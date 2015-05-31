module TaskTest
  ( testMain
  , runTest
  , test, suite
  , succeeds, meets
  , (|>>), (|>+), (|>-)
  ) where

{- A Sketch of a testing framework for task-based code.

This is work in progress.
We aim to make the logging output look much more nicer.
-}

import Signal exposing (Signal, Mailbox, mailbox)
import Task exposing (Task, andThen, onError, fail, succeed)
import Html exposing (Html, div, span, text, a, h1, h2)
import Html.Attributes exposing (href, target, class)
import Debug

-------------------------------------------------------------------------------

type Report = Line Bool String

reports: Mailbox (Maybe Report)
reports = mailbox Nothing

report : String -> String -> Bool -> String -> Task x ()
report context description ok text =
  Signal.send reports.address <|
    Just (Line ok (context ++ ": " ++ description ++ ": " ++ text))

type alias Model = List Report

startModel = []

progression : Maybe Report -> Model -> Model
progression maybeReport model = case maybeReport of
  Just report -> report :: model
  Nothing     -> model

state : Signal Model
state = Signal.foldp progression startModel reports.signal

testMain = Signal.map view state

-------------------------------------------------------------------------------

view : Model -> Html
view model =
  div []
  ( h2 [] [text "Reports"]
    :: viewReports model
  )

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

type alias Context = String
type alias TestTask x a = Context -> (Task x a)

runTest : TestTask x a -> Task x a
runTest testTask = testTask "no test name"

test : Task x a -> TestTask x a
test task = \context -> task

succeeds : String -> TestTask x a -> TestTask x a
succeeds description testTask =
  \context ->
    ( testTask context
      `onError` \err ->
        ( report context description False "task failed"
          `andThen` \_ -> fail err
        )
    )
    `andThen` \val ->
      ( report context description True "task succeeds"
        `andThen` \x -> succeed val
      )

meets : String -> (a -> Bool) -> TestTask x a -> TestTask x a
meets description condition testTask =
  \context ->
    testTask context
    `andThen` \val ->
      ( ( if condition val
            then report context description True  "task result meets the condition"
            else report context description False "task result misses the condition"
        )
        `andThen` \x -> succeed val
      )

infixl 1 |>>
(|>>) : TestTask x a -> (TestTask x a -> TestTask x b) -> TestTask x b
(|>>) = (|>)

infixl 1 |>-
(|>-) : TestTask x a -> Task x b -> TestTask x b
(|>-) testTask1 task2 =
  \context ->
    testTask1 context
    `andThen` \_ -> task2

infixl 1 |>+
(|>+) : TestTask x a -> (a -> TestTask x b) -> TestTask x b
(|>+) testTask1 callback2 =
  \context ->
    testTask1 context
    `andThen` \res1 ->
      let testTask2 = callback2 res1 in
        testTask2 context

suite : String -> TestTask x a -> TestTask x a
suite name testTask =
  \context ->
    testTask name

