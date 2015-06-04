{- A Sketch of a Test App for ElmFire

A given sequence of tasks is run on the Firebase API.

This is work in progress.
-}

import String
import Time
import Task exposing (Task)
import Json.Encode as JE
import Json.Decode as JD
import Html exposing (Html, div, span, text, a, h1, h2)
import Html.Attributes exposing (href, target, class)
import Debug

import TaskTest exposing (..)

import ElmFire exposing (..)

-------------------------------------------------------------------------------

-- Use this test Firebase. The tests below rely on some settings in this Firebase.
-- Individual executions of this test suite use independent branches in this Firebase.
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

action1 : Maybe JE.Value -> Action
action1 maybeValue =
  case maybeValue of
    Just value ->
      case JD.decodeValue JD.string value of
        Ok str -> Set (JE.string <| str ++ "!")
        _ -> Remove
    _ -> Abort

action1AsTask : Maybe JE.Value -> Task () Action
action1AsTask maybeValue =
  Task.succeed (action1 maybeValue)

type Response
  = NoResponse
  | Data Snapshot
  | Canceled Cancellation

test1 =
  sequence  "Test Sequence" (
      test  "open" (open (fromUrl url |> push |> push))
  |>> succeeds
  |>> meets "url of opened ref starts with base-url" (\ref -> url `String.startsWith` toUrl ref )

  |>+ \ref
   -> test  "setWithPriority" (setWithPriority (JE.string "Hello") (NumberPriority 42) (location ref))
  |>> meets "set returned same ref" (\refReturned -> toUrl refReturned == toUrl ref)
  |>> map location
  |>+ \loc
   -> clear

  |>- test  "once valueChanged (at child)" (once valueChanged loc)
  |>> printResult
  |>> meets "once returned same key" (\snapshot -> snapshot.key == key ref)
  |>> meets "once returned right value" (\snapshot -> snapshot.value == Just (JE.string "Hello"))
  |>> meets "once returned right prevKey" (\snapshot -> snapshot.prevKey == Nothing)
  |>> map .priority
  |>> equals "once returned right priority" (NumberPriority 42)

  |>- createReporter "subscription results"
  |>+ \reporter1
   -> test  "subscribe child added (at parent)"
            (subscribe (Data >> reporter1) (Canceled >> reporter1) (child added) (parent loc))
  |>> succeeds
  |>> printResult

  |>- test  "sleep 2s" ( Task.sleep (2 * Time.second) )
  |>- test  "set another child" ( set (JE.string "Elmers") (loc |> parent |> push) )
  |>> map key
  |>> printResult

  |>+ \key
   -> test  "transaction on that child"
            (transaction action1 (loc |> parent |> sub key) True)
  |>> printResult
  |>> meets "committed and returned changed value"
            (\(committed, snapshot) ->
                committed && snapshot.value == Just (JE.string "Elmers!")
            )

  |>- test  "transactionByTask on that child"
            (transactionByTask action1AsTask (loc |> parent |> sub key) True)
  |>> printResult
  |>> meets "committed and returned changed value"
            (\(committed, snapshot) ->
                committed && snapshot.value == Just (JE.string "Elmers!!")
            )

  |>- test  "once valueChanged at non-existing location" (once valueChanged (sub "_non_existing_key_" loc))
  |>> printResult
  |>> meets "returns Nothing" (\snapshot -> snapshot.value == Nothing)

  |>- test  "set without permission"
            ( set (JE.null) (fromUrl url |> root |> sub "unaccessible") )
  |>> printResult
  |>> fails
  |>> errorMeets "reports PermissionError" isPermissionError
  |>- clear

  |>- test  "once without permission"
            ( once valueChanged (fromUrl url |> root |> sub "unaccessible") )
  |>> printResult
  |>> fails
  |>> errorMeets "reports PermissionError" isPermissionError
  |>- clear

  |>- createReporter "subscription without permission results"
  |>+ \reporter2
   -> test  "subscribe without permission"
            ( subscribe (Data >> reporter2) (Canceled >> reporter2)
                        valueChanged (fromUrl url |> root |> sub "unaccessible") )
  |>> printResult
  |>- clear

  |>- test  "transaction without permission"
            (transaction action1 (fromUrl url |> root |> sub "unaccessible") True)
  |>> printResult
  |>> meets "not committed" (\(committed, _) -> not committed)
  |>- clear

  |>- test  "open root's parent" ( open (fromUrl url |> root |> parent) )
  |>> printResult
  |>> fails
  |>> errorMeets "reports LocationError" isLocationError
  |>- clear

  |>- test  "open an invalid URL" ( open (fromUrl "not-a-url") )
  |>> printResult
  |>> fails
  |>> errorMeets "reports LocationError" isLocationError
  |>- clear

  |>- test  "subscribe with invalid URL"
            ( subscribe (always Task.succeed ()) (always Task.succeed ())
                        valueChanged (fromUrl "not-a-url") )
  |>> printResult
  |>> fails
  |>> errorMeets "reports LocationError" isLocationError
  |>- clear

  |>- test  "transaction with invalid URL"
            (transaction action1 (fromUrl "not-a-url") True)
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
