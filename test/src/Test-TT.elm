{- A ElmFire Testing App

A given sequence of tasks is run on the Firebase API.
Steps and results are logged as Html.

This is work in progress.
We aim to make the logging output look much more nicer.
-}

import Signal exposing (Signal, Mailbox, mailbox, message)
import Task exposing (Task, andThen, onError, fail, succeed, sleep)
import Json.Encode as JE
import Time
import Html exposing (Html, div, span, input, output, label, text, a, h1, h2)
import Html.Events exposing (on, targetValue)
import Html.Attributes exposing (href, target, class)
import Debug

import ElmFire exposing (..)

-------------------------------------------------------------------------------

url = "https://elmfire.firebaseio-demo.com/test"

-------------------------------------------------------------------------------


-------------------------------------------------------------------------------

type Report = Line Bool String

reports: Mailbox (Maybe Report)
reports = mailbox Nothing

report : String -> Bool -> String -> Task x ()
report context ok text =
  Signal.send reports.address <|
    Just (Line ok (context ++ ": " ++ text))

type alias Model = List Report

startModel = []

progression : Maybe Report -> Model -> Model
progression maybeReport model = case maybeReport of
  Just report -> report :: model
  Nothing     -> model

state : Signal Model
state = Signal.foldp progression startModel reports.signal

main = Signal.map view state

-------------------------------------------------------------------------------

view : Model -> Html
view model =
  div []
  [ h1  [] [text "ElmFire Test"]
  , div [] [ a [href url, target "_blank"] [text url] ]
  , div [class "reports"] ( h2 [] [text "Reports"] :: viewReports model)
  ]

viewReports : Model -> List Html
viewReports model = List.foldl -- reverses the list for display
  ( \report htmlList -> viewReport report :: htmlList )
  []
  model

viewReport : Report -> Html
viewReport (Line ok txt) =
  div
    [class (if ok then "report success" else "report failure")]
    [text txt]

-------------------------------------------------------------------------------

type TestTask x a = TT String (Task x a)

runTest : TestTask x a -> Task x a
runTest testTask = case testTask of TT _ task -> task

test : String -> Task x a -> TestTask x a
test context task = TT context task

succeeds : TestTask x a -> TestTask x a
succeeds (TT context task) =
  TT context (
    ( task
      `onError` \err ->
        ( report context False "task failed unexpectedly"
          `andThen` \_ -> fail err
        )
    )
    `andThen` \val ->
      ( report context True "task succeeds as expected"
        `andThen` \x -> succeed val
      )
  )

meets : (a -> Bool) -> TestTask x a -> TestTask x a
meets condition (TT context task) =
  TT context (
    task
    `andThen` \val ->
      ( ( if condition val
            then report context True  "successful task meets the condition as expected"
            else report context False "successful task unexpectedly misses the condition"
        )
        `andThen` \x -> succeed val
      )
  )

infixl 0 |>+
(|>+) : TestTask x a -> (a -> Task x b) -> TestTask x b
(|>+) (TT context task1) callback2 =
  TT context (task1 `andThen` callback2)

infixl 0 |>++
(|>++) : TestTask x a -> (a -> String -> TestTask x b) -> TestTask x b
(|>++) (TT context task1) callback2 =
  TT context
    (
    task1
    `andThen` \res ->
      let (TT context2 task2) = (callback2 res context) in
        task2
    )

infixl 0 |>+-
(|>+-) : TestTask x a -> (a -> TestTask x b) -> TestTask x b
(|>+-) (TT context task1) callback2 =
  TT context
    (
    task1
    `andThen` \res ->
      let (TT context2 task2) = (callback2 res) in
        task2
    )

lift : Task x a -> TestTask x a
lift task = TT "lift dummy context" task

infixl 0 |>-
(|>-) : TestTask x a -> Task x b -> TestTask x b
(|>-) (TT context task1) task2 =
 TT context (task1 `andThen` \_ -> task2)

infixl 0 |>>
(|>>) : TestTask x a -> (TestTask x a -> TestTask x b) -> TestTask x b
(|>>) = (|>)


test1 =
  test "test1" ( set (JE.string "value 1") (fromUrl url |> sub "key1") )
  |>> succeeds
  |>> meets (key >> (==) "key1")

  |>- open (fromUrl url |> sub "key2")
  |>+ (\ref2 -> set (JE.string "value 2") (location ref2))
  |>> succeeds
  |>> meets (key >> (==) "key2 BAD")

  |>++ \ref3 c -> test c (set (JE.string "value 3") (location ref3))
  |>> succeeds
  |>> meets (key >> (==) "key3")

  |>+- \ref4 ->
    (
      lift (set (JE.string "value 4") (location ref4))
      |>> succeeds
      |>> meets (key >> (==) "key4")
    )

{-
  |>+ \ref9 ->
        runTest (
          test "999" (set (JE.string "value 9") (location ref9))
          |>> succeeds
        )
-}

port runTasks : Task Error Reference
port runTasks =
  runTest test1


{-
port runTasks : Task Error Reference
port runTasks =
  succeed ()
  |>- fail UnknownQueryId -- TODO: Need better way to abort things!
  |>- set (JE.string "value 1") (fromUrl url |> sub "key1")
  |>  succeedsWhere (key >> (==) "key1")
  |>  succeeds
  |>  meets (key >> (==) "key1")
  |>+ \r -> set (JE.string "value 2") (fromUrl url |> sub "key2")
  |>  succeedsWhere (key >> (==) "key2")
  |>- succeed r
  -- `andThen`
  -- \_ -> (set (JE.string "value 2") (fromUrl url |> sub "key2")) |> succeedsWhere (key >> (==) "key2")
-}
