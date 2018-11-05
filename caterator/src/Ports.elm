port module Ports exposing (ImagePortData, fileContentRead, fileSelected, imageToValue)

import Json.Encode as Encode


type alias ImagePortData =
    { contents : String, filename : String }


imageToValue : ImagePortData -> Encode.Value
imageToValue v =
    Encode.object
        [ ( "contents", Encode.string v.contents )
        , ( "filename", Encode.string v.filename )
        ]


port fileSelected : String -> Cmd msg


port fileContentRead : (ImagePortData -> msg) -> Sub msg
