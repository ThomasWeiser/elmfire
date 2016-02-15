module Main (main) where

import StartApp
import Effects exposing (Never)
import Task
import Signal

import ElmFire exposing (Snapshot)

import Example exposing (..)

app =
  StartApp.start
    { init = init
    , update = update
    , view = view
    , inputs = [ snapshotMailbox.signal ]
    }

main =
    app.html

port tasks : Signal (Task.Task Never ())
port tasks =
    app.tasks

-- port newdata : Signal Snapshot
