{- Basic ElmFire Example App

Write the text from a input field to a Firebase location.
Query that same location and display the result.
Use the displayed link to show the Firebase bashboard for the location.
-}
import Html exposing (Html, div, input, output, label, text, a)
import Html.Events exposing (on, targetValue)
import Html.Attributes exposing (href, target)
import Html.App
import Task exposing (Task)
import Json.Encode as JE
import Json.Decode as JD

import ElmFire.LowLevel exposing
  ( fromUrl, toUrl, set, subscribe, valueChanged, noOrder, noLimit
  , Reference, Snapshot, Subscription, Error
  )

-- Firebase location to access:
-- (You may want to change this url to something you own, but you don't have to)
firebaseUrl : String
firebaseUrl = "https://elmfire.firebaseio-demo.com/example"


main =
  Html.App.program
    { init = init
    , update = update
    , view = view
    , subscriptions = subscriptions
    }


type alias Model = () -- String


type Msg
  = Send String
  | Sent (Result Error ())


init : (Model, Cmd Msg)
init =
  ( ()
  , Cmd.none
  )


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Send text ->
      ( model
      , Task.perform
          (Sent << Err)
          (Sent << Ok << (always ()))
          (set (JE.string text) (fromUrl firebaseUrl))
      )
    Sent result ->
      let _ = Debug.log "Sent" result
      in
        ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none


view : Model -> Html Msg
view model =
  div []
    [ label []
      [ text "Set value: "
      , input
          [ on "input" (JD.map Send targetValue) ]
          []
      ]
    ]
