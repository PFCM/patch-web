port module Ports exposing (ImagePortData, fileContentRead, fileSelected, imageToValue)

import Json.Encode as Encode


type alias ImagePortData =
    { contents : String, filename : String }


imageToValue : Int -> ImagePortData -> Encode.Value
imageToValue s v =
    Encode.object
        [ ( "contents", Encode.string v.contents )
        , ( "filename", Encode.string v.filename )
        , ( "patch_size", Encode.int s )
        ]


port fileSelected : String -> Cmd msg


port fileContentRead : (ImagePortData -> msg) -> Sub msg
