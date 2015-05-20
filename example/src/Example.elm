{- Basic ElmFire Example App

Write the text from a input field to a Firebase location.
Query that same location and display the result.
Use the displayed link to show the Firebase bashboard for the location.
-}
import Html exposing (Html, div, input, output, label, text, a)
import Html.Events exposing (on, targetValue)
import Html.Attributes exposing (href, target)
import Signal exposing (Signal, Mailbox, mailbox, message)
import Task exposing (Task)
import Json.Encode exposing (string, encode)

import ElmFire exposing
  ( location, set, subscribe, valueChanged
  , Response (..), QueryId, Error
  )

-- You may want to change this url
loc = "https://elmfire.firebaseio-demo.com/test"

responses : Signal.Mailbox Response
responses = Signal.mailbox NoResponse

inputString : Mailbox String
inputString = mailbox ""

port runSet : Signal (Task Error ())
port runSet = Signal.map
  (\str -> set (string str) (location loc))
  inputString.signal

port runQuery : Task Error QueryId
port runQuery = subscribe responses.address valueChanged (location loc)

view : Response -> Html
view response =
  let outputText = case response of
    Data dataMsg ->
      Maybe.withDefault "no value" <| Maybe.map (encode 0) dataMsg.value
    otherwise -> "no query response"
  in
  div []
  [ text "ElmFire test at: "
  , a [href loc, target "_blank"] [text loc]
  , div []
    [ label []
      [ text "set value: "
      , input [ on "input" targetValue (message inputString.address) ] []
      ]
    ]
  , div []
    [ label []
      [ text "query result: "
      , output [] [ text outputText ]
      ]
    ]
  ]

main = Signal.map view responses.signal
