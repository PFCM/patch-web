module Main exposing (Model, Msg(..), catButton, imageInput, imageInputId, imagePreview, imageResult, init, main, radio, sizeRadios, sizes, subscriptions, update, view)

import Browser
import Debug
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick)
import Http
import Json.Decode as Decode
import Maybe as M
import Ports
    exposing
        ( ImagePortData
        , fileContentRead
        , fileSelected
        , imageToValue
        )
import String



---- MODEL ----


type alias Model =
    { catSize : Int
    , imageInputData : Maybe ImagePortData
    , imageResultData : Maybe ImagePortData
    , error : Maybe Http.Error
    , waiting : Bool
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { catSize = 32
      , imageInputData = Nothing
      , imageResultData = Nothing
      , error = Nothing
      , waiting = False
      }
    , Cmd.none
    )



---- UPDATE ----


type Msg
    = ChangeCatSize Int
    | ImageSelected
    | ImageRead ImagePortData
    | MakeCatHappen
    | CatHappened (Result Http.Error ImagePortData)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangeCatSize newSize ->
            ( { model | catSize = newSize }, Cmd.none )

        ImageSelected ->
            ( model, fileSelected imageInputId )

        ImageRead newData ->
            ( { model | imageInputData = Just newData }, Cmd.none )

        MakeCatHappen ->
            ( { model | waiting = True }, requestCattery model )

        CatHappened res ->
            case res of
                Ok img ->
                    ( { model | imageResultData = Just img, waiting = False }
                    , Cmd.none
                    )

                Err why ->
                    ( { model | error = Just why, waiting = False }
                    , Cmd.none
                    )


imageDecoder : Decode.Decoder ImagePortData
imageDecoder =
    Decode.map2 ImagePortData
        (Decode.field "contents" Decode.string)
        (Decode.field "filename" Decode.string)


requestCattery : Model -> Cmd Msg
requestCattery model =
    case model.imageInputData of
        Just inp ->
            let
                body =
                    Http.jsonBody << imageToValue <| inp

                request =
                    Http.post "http://%BACKEND_URL%/caterise" body imageDecoder
            in
            Http.send CatHappened request

        Nothing ->
            Cmd.none



---- VIEW ----


imageInputId : String
imageInputId =
    "image-input"


sizes : List Int
sizes =
    [ 8, 16, 32 ]


radio : String -> msg -> Html msg
radio val msg =
    label
        [ style "padding" "20px"
        ]
        [ input [ type_ "radio", name "cat-size", onClick msg ] []
        , text val
        ]


sizeRadios : List Int -> Html Msg
sizeRadios vals =
    div []
        << List.map (\v -> radio (String.fromInt v) (ChangeCatSize v))
    <|
        vals


imageResult : Maybe ImagePortData -> Html Msg
imageResult data =
    div [ class "image-result-wrapper" ]
        [ imagePreview data "%PUBLIC_URL%/baseline-photo-24px.svg" ]


imageInput : Html Msg
imageInput =
    div [ class "image-input-wrapper", style "width" "50%" ]
        [ input
            [ type_ "file"
            , id imageInputId
            , on "change" (Decode.succeed ImageSelected)
            ]
            []
        ]


catButton : Model -> Html Msg
catButton model =
    let
        noInput =
            isNothing <| model.imageInputData

        notActive =
            noInput || model.waiting

        attrs =
            [ class "cat-button-wrapper", style "width" "50%" ]
    in
    div attrs
        [ button [ onClick MakeCatHappen, disabled notActive ] [ text "🐈" ] ]


imagePreview : Maybe ImagePortData -> String -> Html Msg
imagePreview imgData default =
    let
        imgSrc =
            M.withDefault default
                << M.map .contents
            <|
                imgData

        imgTitle =
            M.withDefault "~c a t~" << M.map .filename <| imgData
    in
    div
        [ class "preview-wrapper"
        , style "width" "50%"
        , style "overflow" "hidden"
        , style "display" "flex"
        , style "justify-content" "center"
        , style "align-items" "center"
        ]
        [ img
            [ src imgSrc
            , title imgTitle
            , style "object-fit" "scale-down"
            , style "min-width" "100%"
            , style "min-height" "100%"
            ]
            []
        ]


isNothing : Maybe a -> Bool
isNothing mayb =
    case mayb of
        Just _ ->
            False

        Nothing ->
            True


view : Model -> Html Msg
view model =
    div []
        [ h1 []
            [ text "hello" ]
        , div
            [ class "upload-wrapper" ]
            [ sizeRadios sizes
            , div
                [ style "display" "flex", style "height" "25em" ]
                [ imagePreview model.imageInputData "%PUBLIC_URL%/jeff.gif"
                , imagePreview model.imageResultData <|
                    if isNothing model.imageInputData then
                        "%PUBLIC_URL%/cats.gif"

                    else
                        "%PUBLIC_URL%/baseline-photo-24px.svg"
                , errorDiv model.error
                ]
            , div
                [ style "display" "flex" ]
                [ imageInput, catButton model ]
            ]
        ]


errorDiv : Maybe Http.Error -> Html msg
errorDiv err =
    div
        [ class "error-bar"
        , style "display" <|
            if isNothing err then
                "none"

            else
                "block"
        ]
    <|
        case err of
            Just what ->
                case what of
                    Http.BadUrl url ->
                        [ text url ]

                    Http.Timeout ->
                        [ text "cattering timed out :(" ]

                    Http.NetworkError ->
                        [ text "connection failed :(" ]

                    Http.BadStatus resp ->
                        [ text ("Error: " ++ String.fromInt resp.status.code) ]

                    Http.BadPayload _ _ ->
                        [ text "couldn't handle response" ]

            Nothing ->
                []


subscriptions : Model -> Sub Msg
subscriptions model =
    fileContentRead ImageRead



---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }
