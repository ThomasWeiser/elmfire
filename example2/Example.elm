{- Basic ElmFire Example App using The Elm Architecture

Write the text from a input field to a Firebase location.
Query that same location and display the result.
Use the displayed link to show the Firebase bashboard for the location.
-}
module Example (Action(..), init, update, view, snapshotMailbox) where

import Html exposing (Html, div, input, output, label, text, a)
import Html.Events exposing (on, targetValue)
import Html.Attributes exposing (href, target, type')
import Effects exposing (Effects)
import Task exposing (Task)
import Signal exposing (Mailbox)
import Json.Encode as Encode
import Json.Decode as Json


import ElmFire exposing
  ( fromUrl, set, subscribe, valueChanged, noOrder, noLimit
  , Location, Reference, Snapshot, Subscription, Error
  )

-- You may want to change this url, but you don't have to
url : String
url = "https://elmfire.firebaseio-demo.com/example"

type alias Model =
    { val : String
    , msg : String
    }

init = (Model "" "", subscriber)

-- UPDATE

type Action
    = Input String
    | NewSubscription (Maybe Subscription)
    | NewSnapshot Snapshot
    | SendConfirmation (Maybe Reference)
    | NoOp

update : Action -> Model -> (Model, Effects Action)
update action model =
    case action of
        Input s ->
            ( model
            , setValue s
            )
        NewSubscription sub ->
            ( { model | msg = Maybe.withDefault "Sub Error" (Maybe.map toString sub) }
            , Effects.none
            )
        NewSnapshot ss ->
            let
                newVal =
                    case Json.decodeValue Json.string ss.value of
                        Result.Ok s -> s
                        Result.Err e -> "decode error " ++ (toString e)
            in
            ( { model | val = newVal, msg = "new data" }
            , Effects.none
            )

        SendConfirmation maybeRef ->
            case maybeRef of
                Just ref ->
                    ( model
                    , Effects.none
                    )
                Nothing ->
                    ( { model | msg = "Ref error" }
                    , Effects.none
                    )
        NoOp ->
            ( model, Effects.none )

-- VIEW

view : Signal.Address Action -> Model -> Html
view address model =
    div
        []
        [ div []
            [ text "ElmFire test at: "
            , a [ href url ]
                [ text url ]
            ]
        , div []
            [ text "set value: "
            , input
                [ type' "text"
                , on "input" (Json.map Input targetValue) (Signal.message address) ]
                []
            ]
        , div []
            [ text <| "query result: ￼" ++ model.val ]
        , div [] [ text model.msg ]
        ]

-- EFFECTS

{-| snapshotMailbox partially inspired by https://github.com/thSoft/elm-architecture-tutorial/blob/elmfire/examples/1/Cache.elm -}
snapshotMailbox : Mailbox Action
snapshotMailbox =
    Signal.mailbox NoOp

location : Location
location =
  fromUrl url

doNothing : a -> Task x ()
doNothing = always (Task.succeed ())

subscriber : Effects Action
subscriber =
    subscribe
        (\snapshot ->
            NewSnapshot snapshot
                |> Signal.send snapshotMailbox.address)
        doNothing
        (valueChanged noOrder)
        (fromUrl url)
        |> Task.toMaybe
        |> Task.map NewSubscription
        |> Effects.task

setValue : String -> Effects Action
setValue str =
    set (Encode.string str) location              -- Task Error Reference
        |> Task.toMaybe
        |> Task.map SendConfirmation
        |> Effects.task
