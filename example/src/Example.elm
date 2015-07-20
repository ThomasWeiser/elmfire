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
import Json.Encode as JE exposing (string, encode)

import ElmFire exposing
  ( fromUrl, set, subscribe, valueChanged
  , Reference, Snapshot, Subscription, Error
  )

-- You may want to change this url, but you don't have to
url = "https://elmfire.firebaseio-demo.com/example"

values : Mailbox JE.Value
values = mailbox JE.null

inputString : Mailbox String
inputString = mailbox ""

port runSet : Signal (Task Error Reference)
port runSet = Signal.map
  (\str -> set (string str) (fromUrl url))
  inputString.signal

doNothing : a -> Task x ()
doNothing = always (Task.succeed ())

port runQuery : Task Error Subscription
port runQuery =
    subscribe
        (Signal.send values.address << .value)
        doNothing
        valueChanged
        (fromUrl url)

view : JE.Value -> Html
view value =
  let outputText = encode 0 value
  in
  div []
  [ text "ElmFire test at: "
  , a [href url, target "_blank"] [text url]
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

main = Signal.map view values.signal
