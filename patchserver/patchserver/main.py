"""
Server that provides endpoints for taking images, cattering them into
submission and sending them back.
"""
import contextlib
import io
import logging
import multiprocessing
import os
import warnings
from functools import partial

import flask
import numpy as np
from flask import Flask, request
from PIL import Image, ImageSequence

from patchies.index import img_index
from patchies.pipeline import cats, make_mosaic


@contextlib.contextmanager
def index_from_config(conf, patch_size):
    """get an image index context manager with a bunch of default HNSW
    parameters."""
    index_path = os.path.join(conf['index_path'],
                              'cats-{}-index.bin'.format(patch_size))
    creation_params = {
        'M': 50,
        'indexThreadQty': multiprocessing.cpu_count(),
        'efConstruction': 400,
        'post': 2,
        'skip_optimized_index': 1
    }
    query_params = {'efSearch': 100}
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
        'cats_path': os.getenv('CATS_PATH', '/cats/raw'),
        'index_path': os.getenv('INDEX_PATH', '/cats/indices'),
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


def create_app():
    """check the preprocessed data is all present and correct and then make the
    app. Also injects the config."""
    logging.basicConfig(level=logging.INFO)
    config = _get_config_from_env()
    # make sure it errors out if someone's being unpleasant
    warnings.simplefilter('error', Image.DecompressionBombWarning)
    _check_data(config)
    application = Flask(__name__)
    application.config.update(config)
    return application


app = create_app()


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


@app.route('/caterise', methods=['POST'])
def process():
    """Take an encoded image, spray cats all over it, return"""
    if not request.files:
        app.logger.info('no files found in post')
        return 'nope'
    img = Image.open(request.files['data'])

    app.logger.info('received image %dx%d', img.size[0], img.size[1])
    if 'patch_size' in request.form:
        app.logger.info('requested patch size: %s', request.form['patch_size'])
    else:
        app.logger.info('no patch size specified, using 32')
    patch_size = int(request.form.get('patch_size', 32))
    if patch_size not in app.config['levels']:
        app.logger.info('invalid request for patch size %d', patch_size)
        return 'nope'
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

    return flask.send_file(
        img_bytes,
        mimetype=Image.MIME[img.format],
        attachment_filename=request.files['data'].filename,
        as_attachment=True)


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
