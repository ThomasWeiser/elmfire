effect module ElmFire
    where { subscription = MySub }
    exposing
        ( valueChanged
        )

{-|
First sketch of an ElmFire effect module.

Simplifications:
* Only valueChanged events
* No query options

@docs valueChanged
-}

-- import Process
-- import Json.Decode as JD
-- import Dict exposing (Dict)

import Task exposing (Task)
import ElmFire.Types exposing (..)
import ElmFire.LowLevel as LL
import EffectManager as EM


-- Types


type alias Spec =
    LocationSpec


type alias Tagger msg =
    Result LL.Error LL.Snapshot -> msg


type alias Handle =
    LL.Subscription


type alias State msg =
    { currentSubs : EM.CurrentSubs Spec (Tagger msg) Handle
    }



-- SUBSCRIPTIONS


type MySub msg
    = ValueChanged LocationSpec (Tagger msg)


subMap : (a -> b) -> MySub a -> MySub b
subMap func sub =
    case sub of
        ValueChanged location tagger ->
            ValueChanged location (tagger >> func)


{-| Subscribe to valueChanged ...
-}
valueChanged :
    LL.Location
    -> (Result LL.Error LL.Snapshot -> msg)
    -> Sub msg
valueChanged (Location locationSpec) tagger =
    subscription (ValueChanged locationSpec tagger)



-- MANAGER


init : Task Never (State msg)
init =
    Task.succeed
        (State EM.emptySubs)


type SelfMsg
    = NewSnapshot LocationSpec LL.Snapshot


onEffects :
    Platform.Router msg SelfMsg
    -> List (MySub msg)
    -> State msg
    -> Task Never (State msg)
onEffects router mySubs state =
    let
        requestedSubs =
            EM.requestedSubsFromList
                (\(ValueChanged spec tagger) -> ( spec, tagger ))
                mySubs

        alterations =
            EM.alterations requestedSubs state.currentSubs

        onAlteration :
            EM.Alteration LocationSpec (Tagger msg) LL.Subscription
            -> State msg
            -> Task Never (State msg)
        onAlteration alteration state =
            case alteration of
                EM.Create locationSpec taggers ->
                    LL.subscribe
                        (\snapshot -> Platform.sendToSelf router (NewSnapshot locationSpec snapshot))
                        (\cancellation -> Task.succeed ())
                        -- TODO: Handle cancellation
                        (LL.valueChanged LL.noOrder)
                        (Location locationSpec)
                        |> Task.map
                            (\lowLevelSub ->
                                { currentSubs =
                                    EM.insertSub locationSpec taggers lowLevelSub state.currentSubs
                                }
                            )
                        |> (flip Task.onError)
                            (\llError ->
                                Task.succeed state
                             -- TODO: Handle error
                            )

                EM.Update locationSpec lowLevelSub taggers ->
                    Task.succeed
                        { currentSubs =
                            EM.insertSub locationSpec taggers lowLevelSub state.currentSubs
                        }

                EM.Delete locationSpec lowLevelSub ->
                    LL.unsubscribe lowLevelSub
                        |> Task.map
                            (\_ ->
                                { currentSubs =
                                    EM.removeSub locationSpec state.currentSubs
                                }
                            )
                        |> (flip Task.onError)
                            (\llError ->
                                Task.succeed state
                             -- TODO: Handle error
                            )
    in
        alterations
            |> chain onAlteration state



{-
   chain_Recursive : (a -> b -> Task x b) -> b -> List a -> Task x b
   chain_Recursive stepTask start list =
       case list of
           [] ->
               Task.succeed start

           elem :: rest ->
               (stepTask elem start)
                   `Task.andThen` \stepResult -> chain stepTask stepResult rest
-}


chain : (a -> b -> Task x b) -> b -> List a -> Task x b
chain step start list =
    List.foldl
        (\elem intermediateTask ->
            intermediateTask
                `Task.andThen` step elem
        )
        (Task.succeed start)
        list


onSelfMsg :
    Platform.Router msg SelfMsg
    -> SelfMsg
    -> State msg
    -> Task Never (State msg)
onSelfMsg router (NewSnapshot locationSpec snapshot) state =
    case EM.getSub locationSpec state.currentSubs of
        Nothing ->
            Task.succeed state

        Just ( taggers, lowLevelSub ) ->
            taggers
                |> List.map (\tagger -> Platform.sendToApp router (tagger (Ok snapshot)))
                |> Task.sequence
                |> Task.map (\_ -> state)
