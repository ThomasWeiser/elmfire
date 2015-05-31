{- A Sketch of a Test App for ElmFire

A given sequence of tasks is run on the Firebase API.

This is work in progress.
-}

import Task exposing (Task)
import Json.Encode as JE
import Debug
import String

import TaskTest exposing (..)

import ElmFire exposing (..)

-------------------------------------------------------------------------------

url = "https://elmfire.firebaseio-demo.com/test"

-------------------------------------------------------------------------------


test1 =
  suite "test1" <|
      test ( open (fromUrl url |> push) )
  |>> succeeds "open"
  |>> meets "opened ref" (\ref -> url `String.startsWith` toUrl ref )

  |>+ \ref -> test ( setWithPriority (JE.string "Hello Elmies") (NumberPriority 42) (location ref) )
  |>> succeeds "set"
  |>> meets "set returned same ref" (\refSet -> toUrl refSet == toUrl ref)

  |>- (once valueChanged (location ref))
  |>> succeeds "once valueChanged (at child)"
  |>> meets "once returned same key" (\snapshot -> snapshot.key == key ref)
  |>> meets "once returned right value" (\snapshot -> snapshot.value == Just (JE.string "Hello Elmies"))
  |>> meets "once returned right priority" (\snapshot -> snapshot.priority == NumberPriority 42)

  |>- (once (child added) (fromUrl url))
  |>> succeeds "once child added (at parent)"
  |>> meets "once returned right value" (\snapshot -> snapshot.value == Just (JE.string "Hello Elmies"))
  |>> meets "once returned right prevKey" (\snapshot -> snapshot.prevKey == Nothing)

port runTasks : Task Error Snapshot
port runTasks = runTest test1

main = testMain
