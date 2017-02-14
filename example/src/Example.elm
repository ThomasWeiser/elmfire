{- Basic ElmFire Example App

   Write the text from a input field to a Firebase location.
   Query that same location and display the result.
   Use the displayed link to show the Firebase bashboard for the location.
-}


module Main exposing (..)

import Html exposing (Html, div, input, output, label, text, a, button)
import Html.Events exposing (on, targetValue, onClick)
import Html.Attributes exposing (href, target)
import Html.App
import Task exposing (Task)
import Json.Encode as JE
import Json.Decode as JD
import ElmFire.LowLevel
    exposing
        ( fromUrl
        , toUrl
        , set
        , subscribe
        , valueChanged
        , noOrder
        , noLimit
        , Reference
        , Snapshot
        , Subscription
        , Error
        , Location
        )
import ElmFire
import ElmFire.Auth.LowLevel
    exposing
        ( authenticate
        , rememberDefault
        , withPassword
        )


-- Firebase location to access:
-- (You may want to change this url to something you own, but you don't have to)


firebaseUrl : String
firebaseUrl =
    "https://elmfire-test.firebaseio.com/"


location : Location
location =
    (fromUrl firebaseUrl "example")


main : Program Never
main =
    Html.App.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias Model =
    String



-- String


type Msg
    = Send String
    | Sent (Result Error ())
    | ValueChanged (Result Error Snapshot)
    | Login


init : ( Model, Cmd Msg )
init =
    ( ""
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Send text ->
            ( model
            , Task.perform
                (Sent << Err)
                (Sent << Ok << (always ()))
                (set (JE.string text) location)
            )

        Sent result ->
            let
                _ =
                    Debug.log "Sent" result
            in
                ( model, Cmd.none )

        ValueChanged result ->
            case result of
                Ok snapshot ->
                    ( toString (snapshot.value), Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        Login ->
            ( model
            , Task.perform
                (Sent << Err)
                (Sent << Ok << (always ()))
                (authenticate location [ rememberDefault ] (withPassword "test@test.com" "123test"))
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    ElmFire.valueChanged location ValueChanged


view : Model -> Html Msg
view model =
    div []
        [ text "ElmFire test at: "
        , a [ href firebaseUrl, target "_blank" ] [ text firebaseUrl ]
        , div []
            [ label []
                [ text "set value: "
                , input [ on "input" (JD.map Send targetValue) ] []
                ]
            ]
        , div []
            [ label []
                [ text "query result: "
                , output [] [ text model ]
                ]
            ]
        , button [ onClick Login ] [ text "Login" ]
        ]
