{- A Sketch of a Test App for ElmFire

A given sequence of tasks is run on the Firebase API.

This is work in progress.
-}

import String
import Task exposing (Task)
import Json.Encode as JE
import Html exposing (Html, div, span, text, a, h1, h2)
import Html.Attributes exposing (href, target, class)
import Debug

import TaskTest exposing (..)

import ElmFire exposing (..)

-------------------------------------------------------------------------------

url = "https://elmfire.firebaseio-demo.com/test"

-------------------------------------------------------------------------------


test1 =
  sequence "test1" (
      test "open" ( open (fromUrl url |> push) )
  |>> succeeds
  |>> meets "url of opened ref starts with base-url" (\ref -> url `String.startsWith` toUrl ref )

  |>+ \ref -> test "setWithPriority" ( setWithPriority (JE.string "Hello Elmies") (NumberPriority 42) (location ref) )
  |>> succeeds
  |>> meets "set returned same ref" (\refSet -> toUrl refSet == toUrl ref)

  |>- test "once valueChanged (at child)" (once valueChanged (location ref))
  |>> succeeds
  |>> meets "once returned same key" (\snapshot -> snapshot.key == key ref)
  |>> meets "once returned right value" (\snapshot -> snapshot.value == Just (JE.string "Hello Elmies"))
  |>> meets "once returned right priority" (\snapshot -> snapshot.priority == NumberPriority 42)

  |>- test "once child added (at parent)" (once (child added) (fromUrl url))
  |>> succeeds
  |>> meets "once returned right value" (\snapshot -> snapshot.value == Just (JE.string "Hello Elmies"))
  |>> meets "once returned right prevKey" (\snapshot -> snapshot.prevKey == Nothing)
  )

port runTasks : Task Error Snapshot
port runTasks = runTest test1

view : Html -> Html
view testDisplay =
  div []
  [ h1  [] [text "ElmFire Test"]
  , div [] [ a [href url, target "_blank"] [text url] ]
  , h2 [] [text "Test Report:"]
  , testDisplay
  ]

main = Signal.map view testDisplay
