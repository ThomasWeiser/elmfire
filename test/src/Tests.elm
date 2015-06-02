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

url = "https://elmfiretest.firebaseio.com/test"

-------------------------------------------------------------------------------

isLocationError : Error -> Bool
isLocationError err =
  case err of
    LocationError _ -> True
    _ -> False

isPermissionError : Error -> Bool
isPermissionError err =
  case err of
    PermissionError _ -> True
    _ -> False

type Response
  = NoResponse
  | Data Snapshot
  | Canceled Cancellation

test1 =
  sequence "test1" (
      test "clear test location" ( remove (fromUrl url) )
  |>> succeeds

  |>- test "open" ( open (fromUrl url |> push) )
  |>> succeeds
  |>> meets "url of opened ref starts with base-url" (\ref -> url `String.startsWith` toUrl ref )

  |>+ \ref
   -> test "setWithPriority" ( setWithPriority (JE.string "Hello Elmies") (NumberPriority 42) (location ref) )
  |>> meets "set returned same ref" (\refReturned -> toUrl refReturned == toUrl ref)
  |>> map location
  |>+ \loc
   -> clear

  |>- test "once valueChanged (at child)" (once valueChanged loc)
  |>> printResult
  |>> meets "once returned same key" (\snapshot -> snapshot.key == key ref)
  |>> meets "once returned right value" (\snapshot -> snapshot.value == Just (JE.string "Hello Elmies"))
  |>> meets "once returned right prevKey" (\snapshot -> snapshot.prevKey == Nothing)
  |>> map .priority
  |>> equals "once returned right priority" (NumberPriority 42)

  |>- createReporter "subscription results"
  |>+ \reporter1
   -> test "subscribe child added (at parent)"
           (subscribe (Data >> reporter1) (Canceled >> reporter1) (child added) (fromUrl url))
  |>> succeeds
  |>> printResult

  |>- test "set without permission" ( set (JE.null) (fromUrl url |> root |> sub "unaccessible") )
  |>> printResult
  |>> fails
  |>> errorMeets "reports LocationError when locating root's parent" isPermissionError
  |>- clear

  |>- test "open root's parent" ( open (fromUrl url |> root |> parent) )
  |>> printResult
  |>> fails
  |>> errorMeets "reports LocationError when locating root's parent" isLocationError
  |>- clear

  |>- test "open an invalid URL" ( open (fromUrl "not-a-url") )
  |>> printResult
  |>> fails
  |>> errorMeets "reports LocationError" isLocationError
  |>- clear

  |>- clear
  )

port runTasks : Task Error ()
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
