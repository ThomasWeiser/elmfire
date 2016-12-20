module Main exposing (..)

import Array exposing (Array)
import Html exposing (..)
import Html.Attributes as HA
import Html.App as App
import Task
import Process
import Time exposing (Time)
import Json.Encode as JE
import Json.Decode as JD
import Date
import ElmFire.LowLevel as LL
import ElmFire


testUrl : String
testUrl =
    "https://elmfiretest.firebaseio.com/test"


testLocation : LL.Location
testLocation =
    LL.fromUrl testUrl


main : Program Never
main =
    App.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type Response
    = ValueChanged (Result LL.Error LL.Snapshot)


responseIsValueChanged : Response -> Bool
responseIsValueChanged response =
    True


type alias Model =
    { startDate : String
    , keyPushed : String
    , log : Array LogEntry
    , subs : List (Sub Action)
    , waiting : Maybe ( Int, Response -> Bool, Action )
    , responses : Maybe (List Response)
    }


type LogEntry
    = LogString String
    | LogStep String
    | LogSnapshot LL.Snapshot
    | LogResponse Response


type Action
    = End
    | Fatal String
    | SubResponse Response
    | Timeout Step
    | Step Step


type Step
    = SetDate String
    | Clear
    | Subscribe
    | Timeout1
    | CheckResponse1
    | Push
    | Once LL.Reference
    | Check LL.Snapshot
    | CheckResponse2


init : ( Model, Cmd Action )
init =
    ( { startDate = "[Date.now]"
      , keyPushed = ""
      , log = Array.empty
      , subs = []
      , waiting = Nothing
      , responses = Nothing
      }
    , Task.perform
        (\_ -> Fatal "Task Date.now failed. Should never happen.")
        (\date -> Step (SetDate (toString date)))
        Date.now
    )


next : Action -> Cmd Action
next action =
    Task.perform
        (\_ -> Debug.crash "Task.succeed failed.")
        identity
        (Task.succeed action)


nextStep : Step -> Cmd Action
nextStep step =
    next (Step step)


defer : Time -> Action -> Cmd Action
defer time action =
    Task.perform
        (\_ -> Debug.crash "Process.sleep failed.")
        identity
        (Process.sleep time
            |> Task.map (always action)
        )


await : Time -> Int -> (Response -> Bool) -> Step -> Step -> Model -> ( Model, Cmd Action )
await maxTime numberOfResponses filter onTimeout onSuccess model =
    case model.waiting of
        Just _ ->
            Debug.crash "Already waiting"

        Nothing ->
            if numberOfResponses < 0 then
                Debug.crash "Cannot await a negative number of responses"
            else if numberOfResponses == 0 then
                ( model, nextStep onSuccess )
            else
                ( { model | waiting = Just ( numberOfResponses, filter, Step onSuccess ) }
                    |> display (LogString ("awaiting " ++ toString numberOfResponses ++ " responses with timeout " ++ toString maxTime))
                , defer maxTime (Timeout onTimeout)
                )


gatherResponses : Model -> Model
gatherResponses model =
    { model | responses = Just [] }


ignoreResponses : Model -> Model
ignoreResponses model =
    { model | responses = Nothing }


noticeResponse : Response -> Model -> ( Model, Cmd Action )
noticeResponse response model =
    let
        model1 =
            case model.responses of
                Nothing ->
                    model

                Just priorResponses ->
                    { model | responses = Just (response :: priorResponses) }
    in
        case model1.waiting of
            Nothing ->
                ( model1, Cmd.none )

            Just ( number, filter, action ) ->
                if filter response then
                    if number > 1 then
                        ( { model1 | waiting = Just ( number - 1, filter, action ) }
                        , Cmd.none
                        )
                    else
                        ( { model1 | waiting = Nothing }
                        , next action
                        )
                else
                    ( model1, Cmd.none )


testResponses : (List Response -> Maybe String) -> Model -> Model
testResponses testFunction model =
    model
        |> (case model.responses of
                Nothing ->
                    display <| LogString "Bad test sequence: Testing responses without gathering them."

                Just responses ->
                    display <|
                        LogString
                            (case testFunction responses of
                                Nothing ->
                                    "testResponses passes"

                                Just message ->
                                    "testResponses fails: " ++ message
                            )
           )
        |> ignoreResponses


display : LogEntry -> Model -> Model
display logEntry model =
    { model | log = Array.push logEntry model.log }


update : Action -> Model -> ( Model, Cmd Action )
update action model =
    case action of
        End ->
            ( display (LogStep "End of test sequence") model
            , Cmd.none
            )

        Fatal description ->
            ( display (LogString ("Fatal: " ++ description)) model
            , Cmd.none
            )

        SubResponse response ->
            model
                |> display (LogResponse response)
                |> noticeResponse response

        Timeout timeoutStep ->
            case model.waiting of
                Nothing ->
                    ( model, Cmd.none )

                Just ( number, _, _ ) ->
                    ( { model | waiting = Nothing }
                        |> display
                            (LogString
                                ("timeout while waiting for "
                                    ++ if number == 1 then
                                        "response"
                                       else
                                        (toString number) ++ " more responses"
                                )
                            )
                    , nextStep timeoutStep
                    )

        Step step ->
            updateStep step model


updateStep : Step -> Model -> ( Model, Cmd Action )
updateStep step model =
    case step of
        SetDate dateString ->
            ( { model | startDate = dateString }
                |> display (LogStep "SetDate")
            , nextStep Clear
            )

        Clear ->
            ( model |> display (LogStep "Clear") |> gatherResponses
            , Task.perform
                (\error -> Fatal error.description)
                (\ref -> Step Subscribe)
                (LL.remove testLocation)
              -- (LL.remove (testLocation |> LL.child "test the test: don't remove path"))
            )

        Subscribe ->
            { model | subs = [ ElmFire.valueChanged testLocation (SubResponse << ValueChanged) ] }
                |> display (LogStep "Subscribing to valueChanges")
                |> await 4000 1 responseIsValueChanged Timeout1 CheckResponse1

        Timeout1 ->
            ( model
                |> display (LogString "Missing initial response from valueChanged subscription")
            , nextStep Push
            )

        CheckResponse1 ->
            ( model
                |> testResponses check_ValueChanged_NonExisting
            , nextStep Push
            )

        Push ->
            ( model
                |> display (LogStep "About to push")
                |> gatherResponses
            , Task.perform
                (\error -> Fatal error.description)
                (\ref -> Step (Once ref))
                (LL.set
                    (JE.string model.startDate)
                    -- (JE.string (model.startDate ++ " BUG-TEST"))
                    (testLocation |> LL.push)
                )
            )

        Once ref ->
            ( { model | keyPushed = LL.key ref }
                |> display (LogString ("pushed to: " ++ LL.toUrl ref))
            , Task.perform
                (\error -> Fatal error.description)
                (\snap -> Step (Check snap))
                (LL.once
                    (LL.valueChanged LL.noOrder)
                    (LL.location ref)
                )
            )

        Check snap ->
            ( model
                |> display (LogSnapshot snap)
                |> display
                    (LogString
                        (case JD.decodeValue JD.string snap.value of
                            Err err ->
                                err

                            Ok string ->
                                if string == model.startDate then
                                    "Value as expected"
                                else
                                    "Unexpected value"
                        )
                    )
            , nextStep CheckResponse2
            )

        CheckResponse2 ->
            ( model
                |> testResponses (check_ValueChanged_Key_String ( model.keyPushed, model.startDate ))
            , next End
            )


check_ValueChanged_NonExisting : List Response -> Maybe String
check_ValueChanged_NonExisting responses =
    case responses of
        [] ->
            Just "Missing response from valueChanged subscription"

        [ ValueChanged (Ok { existing }) ] ->
            if existing then
                Just "got a value, should be non-existing"
            else
                Nothing

        _ :: _ ->
            Just "Got more than one response"


check_ValueChanged_Key_String : ( String, String ) -> List Response -> Maybe String
check_ValueChanged_Key_String ( key, str ) responses =
    case responses of
        [] ->
            Just "Missing response from valueChanged subscription"

        [ ValueChanged (Ok { value }) ] ->
            case
                JD.decodeValue
                    (JD.at [ key ] JD.string)
                    value
            of
                Ok s ->
                    if s == str then
                        Nothing
                    else
                        Just "Unexpected value in response"

                Err err ->
                    Just ("Unexpected value in response: " ++ err)

        [ response ] ->
            Just "Unexpected response"

        _ :: _ ->
            Just "Got more than one response"


subscriptions : Model -> Sub Action
subscriptions model =
    Sub.batch model.subs


view : Model -> Html Action
view model =
    div []
        [ div []
            [ a [ HA.href testUrl, HA.target "_blank" ] [ text testUrl ] ]
        , div [] [ text model.startDate ]
        , hr [] []
        , div [] (viewLog model.log)
        ]


viewLog : Array LogEntry -> List (Html Action)
viewLog log =
    List.map viewLogEntry (Array.toList log)


viewLogEntry : LogEntry -> Html Action
viewLogEntry entry =
    case entry of
        LogString logText ->
            div [] [ text logText ]

        LogStep logText ->
            div
                [ HA.class "step" ]
                [ text logText ]

        LogSnapshot snapshot ->
            viewSnapshot snapshot

        LogResponse response ->
            viewResponse response


viewSnapshot : LL.Snapshot -> Html Action
viewSnapshot { key, existing, value, prevKey, priority } =
    table []
        [ thead []
            [ tr []
                [ th [] [ text "existing" ]
                , th [] [ text "key" ]
                , th [] [ text "value" ]
                , th [] [ text "prevKey" ]
                , th [] [ text "priority" ]
                ]
            ]
        , tbody []
            [ tr []
                [ td [] [ text (toString existing) ]
                , td [] [ text key ]
                , td [] [ text (toString value) ]
                , td [] [ text (toString prevKey) ]
                , td [] [ text (toString priority) ]
                ]
            ]
        ]


viewResponse : Response -> Html Action
viewResponse (ValueChanged result) =
    div []
        [ text "Response"
        , case result of
            Err error ->
                viewError error

            Ok snapshot ->
                viewSnapshot snapshot
        ]


viewError : LL.Error -> Html Action
viewError { description } =
    text description
