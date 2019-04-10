"""
Server that provides endpoints for taking images, cattering them into
submission and sending them back.
"""
import base64
import contextlib
import io
import json
import logging
import multiprocessing
import os
import re
import warnings
from functools import partial

import flask
import numpy as np
from flask import Flask, request
from google.cloud import storage
from PIL import Image, ImageSequence

from patchies.index import img_index
from patchies.pipeline import cats, make_mosaic

gcs_client = storage.Client()


def _download_bucket_to(bucket_name, path):
    """download the contents of a gcs bucket to a given directory."""
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    for blob in bucket.list_objects():
        fname = os.path.join(path, blob.name)
        blob.download_to_filename(fname)


def _get_blob(bucket, obj, path):
    """attempt to get a blob from a bucket and write it into path"""
    app.logger.info('attempting to get gs://%s/%s to %s', bucket, obj, path)
    blob = storage.Blob(obj, bucket)
    blob.download_to_filename(os.path.join(path, obj), gcs_client)


def _get_cats(patch_size):
    """try and get a level of cats"""
    bucket = os.getenv('GCP_CATS_BUCKET')
    if not bucket:
        app.logger.error('no cats bucket set 😿')
        raise ValueError('no cats bucket set 😿')
    cat_dir = os.getenv('CATS_PATH', '/tmp/cats/raw')
    idx_dir = os.getenv('INDEX_PATH', '/tmp/cats/indices')
    _get_blob(bucket, 'cats-{}-index.bin'.format(patch_size), idx_dir)
    _get_blob(bucket, 'cats-{}.npy'.format(patch_size), cat_dir)


@contextlib.contextmanager
def index_from_config(conf, patch_size):
    """get an image index context manager with a bunch of default HNSW
    parameters."""
    index_path = os.path.join(conf['index_path'],
                              'cats-{}-index.bin'.format(patch_size))
    if not os.path.exists(index_path):
        _get_cats(patch_size)

    creation_params = {
        'M': 50,
        'indexThreadQty': multiprocessing.cpu_count(),
        'efConstruction': 400,
        'post': 2,
        'skip_optimized_index': 1
    }
    query_params = {'efSearch': 1000}
    loader = partial(cats, conf['cats_path'], patch_size)
    with img_index(
            index_path,
            loader,
            construction_args=creation_params,
            query_args=query_params) as stuff:
        yield stuff


def _get_config_from_env():
    """Get config from environment variables if possible. Tries to populate
    sensible defaults, if that fails raises an error."""
    levels = os.getenv('LEVELS', '2,4,8,16,32,64')
    levels = [int(l) for l in levels.split(',')]
    return {
        'cats_path': os.getenv('CATS_PATH', '/tmp/cats/raw'),
        'index_path': os.getenv('INDEX_PATH', '/tmp/cats/indices'),
        'levels': levels
    }


def _check_data(config):
    """Check the pre-processed data exists where it should (just by asking for
    it)"""
    logging.info('checking that the data is ok')
    logging.info('cats should be in `%s`', config['cats_path'])
    logging.info('indices should be in `%s`', config['index_path'])
    for patch_size in config['levels']:
        logging.info('checking level %d', patch_size)
        with index_from_config(config, patch_size) as (_, data):
            logging.info('~~~~~~~shape %s', data.shape)


def create_app(app_cls):
    """check the preprocessed data is all present and correct and then make the
    app. Also injects the config."""
    logging.basicConfig(level=logging.INFO)
    config = _get_config_from_env()
    # make sure it errors out if someone's being unpleasant
    warnings.simplefilter('error', Image.DecompressionBombWarning)
    _check_data(config)
    application = app_cls(__name__)
    application.config.update(config)
    return application


app = create_app(Flask)


def _slice_params(axis, factor):
    """Get the start and stop indices to slice a dimension of size `axis` into
    a multiple of `factor`, keeping it centered."""
    new_size = (axis // factor) * factor
    start = (axis - new_size) // 2
    end = axis - (axis - new_size - start)
    return start, end


def catsup(index, data, img, patch_size):
    """cat a single image."""
    img = np.array(img)
    x_start, x_end = _slice_params(img.shape[0], patch_size)
    y_start, y_end = _slice_params(img.shape[1], patch_size)
    img = img[x_start:x_end, y_start:y_end, :]
    img = make_mosaic(index, img, patch_size, data)
    # re-PIL it
    return Image.fromarray(img)


def process_image(img_file, patch_size):
    """process a file-like object as an image"""
    img = Image.open(img_file)

    app.logger.info('received image %dx%d', img.size[0], img.size[1])
    app.logger.info('using patch size %d', patch_size)
    if patch_size not in app.config['levels']:
        app.logger.info('invalid request for patch size %d', patch_size)
        return None, 'invalid patch size'
    app.logger.info('expecting cats to be at %s', app.config['cats_path'])
    with index_from_config(app.config, patch_size) as stuff:
        index, data = stuff
        frames = [
            catsup(index, data, frame.convert('RGB'), patch_size)
            for frame in ImageSequence.Iterator(img)
        ]
        app.logger.info('%d frame%s', len(frames), 's'
                        if len(frames) > 1 else '')

    img_bytes = io.BytesIO()
    if len(frames) > 1:
        # for gif we are going to have to convert back to paletted
        frames[0].save(
            img_bytes,
            format=img.format,
            append_images=frames[1:],
            save_all=True,
            loop=img.info.get('loop', 0),
            duration=img.info.get('duration', 200))
    else:
        # NOTE: this is a bit dumb
        frames[0].save(img_bytes, format=img.format)
    # get back to the start of the fake file to send it
    img_bytes.seek(0)

    return img_bytes, img.format


def process_json(req):
    """Handle json POST requests to the endpoint. Assumes the image is
    base64 encoded in the "contents" field and allows a "patch_size" integer
    field to choose the patch size."""
    patch_size = int(req.json.get('patch_size', 32))
    contents = re.sub(r'data:image/.+;base64', '', request.json['contents'])
    contents = base64.b64decode(contents)
    img_bytes, format = process_image(io.BytesIO(contents), patch_size)
    contents = base64.b64encode(img_bytes.getvalue()).decode('utf-8')
    contents = 'data:image/{};charset=utf-8;base64,{}'.format(
        format.lower(), contents)
    return {'contents': contents, 'filename': format, 'mime_type': format}


@app.route('/caterise', methods=['POST'])
def process():
    """Take an encoded image, spray cats all over it, return"""
    if request.json:
        return flask.jsonify(process_json(request))
    return flask.jsonify({'message': 'lol noo'})


def cf_process(request):
    """the entrypoint for a cloud-function http request"""
    if request.method == "OPTIONS":
        # allow CORS
        headers = {
            'Access-Control-Allow-Origin': '*',  # TODO(pfcm): be more precise?
            'Access-Control-Allow-Methods': 'GET',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Max-Age': '3600'
        }
        return ('', 204, headers)
    headers = {'Access-Control-Allow-Origin': '*'}
    return (json.dumps(process_json(request)), 200, headers)


if __name__ == '__main__':
    app = create_app(Flask)
    app.run(debug=True, host='0.0.0.0')
