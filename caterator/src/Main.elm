module Main exposing (Model, Msg(..), catButton, imageInput, imageInputId, imagePreview, imageResult, init, main, radio, sizeRadios, sizes, subscriptions, update, view)

import Browser
import Debug
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick)
import Json.Decode as JD
import Maybe as M
import Ports exposing (ImagePortData, fileContentRead, fileSelected)
import String



---- MODEL ----


type alias Model =
    { catSize : Int
    , imageInputData : Maybe ImagePortData
    , imageResultData : Maybe ImagePortData
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { catSize = 32, imageInputData = Nothing, imageResultData = Nothing }
    , Cmd.none
    )



---- UPDATE ----


type Msg
    = ChangeCatSize Int
    | ImageSelected
    | ImageRead ImagePortData


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ChangeCatSize newSize ->
            ( { model | catSize = newSize }, Cmd.none )

        ImageSelected ->
            ( model, fileSelected <| Debug.log "image input changed: " imageInputId )

        ImageRead newData ->
            ( { model | imageInputData = Just newData }, Cmd.none )



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
            , on "change" (JD.succeed ImageSelected)
            ]
            []
        ]


catButton : Model -> Html Msg
catButton model =
    div [ class "cat-button-wrapper", style "width" "50%" ]
        [ button [] [ text "🐈" ] ]


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


view : Model -> Html Msg
view model =
    div []
        [ h1 []
            [ text "are you my friend?" ]
        , div
            [ class "upload-wrapper" ]
            [ sizeRadios sizes
            , div
                [ style "display" "flex", style "height" "25em" ]
                [ imagePreview model.imageInputData "%PUBLIC_URL%/jeff.gif"
                , imagePreview model.imageResultData "%PUBLIC_URL%/cats.gif"
                ]
            , div
                [ style "display" "flex" ]
                [ imageInput, catButton model ]
            ]
        ]


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
