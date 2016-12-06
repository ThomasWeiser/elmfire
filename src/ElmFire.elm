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
* Fixed Firebase location

Notes:
* Doesn't spawn a process like most other effect modules do. Ok?

@docs valueChanged
-}

-- import Dict
-- import Process
-- import Json.Decode as JD

import Task exposing (Task)
import ElmFire.LowLevel as LL


-- SUBSCRIPTIONS


type MySub msg
    = ValueChanged
        -- Location
        (Result LL.Error LL.Snapshot -> msg)


subMap : (a -> b) -> MySub a -> MySub b
subMap func sub =
    case sub of
        ValueChanged tagger ->
            ValueChanged (tagger >> func)


{-| Subscribe to valueChanged ...
-}
valueChanged :
    -- Location ->
    (Result LL.Error LL.Snapshot -> msg)
    -> Sub msg
valueChanged tagger =
    subscription (ValueChanged tagger)



-- MANAGER


type alias State msg =
    { subs : SubsDict msg
    }


type alias SubsDict msg =
    -- Dict.Dict Location
    Maybe (ValueChangedSubscription msg)


type alias ValueChangedSubscription msg =
    { subscribers : List (Result LL.Error LL.Snapshot -> msg)
    , lowLevelSubscription : LL.Subscription
    }


init : Task Never (State msg)
init =
    Task.succeed
        (State
            -- Dict.empty
            Nothing
        )


(&>) : Task x a -> Task x b -> Task x b
(&>) t1 t2 =
    Task.andThen t1 (\_ -> t2)


type SelfMsg
    = NewSnapshot LL.Snapshot



--   NewLowLevelSub Subscription


onEffects :
    Platform.Router msg SelfMsg
    -> List (MySub msg)
    -> State msg
    -> Task Never (State msg)
onEffects router mySubs state =
    case ( mySubs, state.subs ) of
        ( [], Nothing ) ->
            Task.succeed state

        ( [], Just { subscribers, lowLevelSubscription } ) ->
            LL.unsubscribe lowLevelSubscription
                |> Task.map
                    (\_ -> { subs = Nothing })
                |> (flip Task.onError)
                    (\llError ->
                        Task.succeed { subs = Nothing }
                     -- TODO: Handle error
                    )

        ( _ :: _, Nothing ) ->
            (LL.subscribe
                (\snapshot -> Platform.sendToSelf router (NewSnapshot snapshot))
                (\cancellation -> Task.succeed ())
                -- TODO: Handle cancellation
                (LL.valueChanged LL.noOrder)
                (LL.fromUrl "https://elmfiretest.firebaseio.com/test")
            )
                |> Task.map
                    (\lowLevelSubscription ->
                        { subs =
                            Just
                                { subscribers = buildSubscriberList mySubs
                                , lowLevelSubscription = lowLevelSubscription
                                }
                        }
                    )
                |> (flip Task.onError)
                    (\llError ->
                        Task.succeed { subs = Nothing }
                     -- TODO: Handle error
                    )

        ( _ :: _, Just { subscribers, lowLevelSubscription } ) ->
            Task.succeed
                { subs =
                    (Just
                        { subscribers = buildSubscriberList mySubs
                        , lowLevelSubscription = lowLevelSubscription
                        }
                    )
                }


buildSubscriberList : List (MySub msg) -> List (Result LL.Error LL.Snapshot -> msg)
buildSubscriberList mySubs =
    List.map
        (\mySub ->
            case mySub of
                ValueChanged tagger ->
                    tagger
        )
        mySubs


onSelfMsg :
    Platform.Router msg SelfMsg
    -> SelfMsg
    -> State msg
    -> Task Never (State msg)
onSelfMsg router selfMsg state =
    case ( selfMsg, state.subs ) of
        ( _, Nothing ) ->
            Task.succeed state

        ( NewSnapshot snapshot, Just { subscribers, lowLevelSubscription } ) ->
            subscribers
                |> List.map (\tagger -> Platform.sendToApp router (tagger (Ok snapshot)))
                |> Task.sequence
                |> Task.map (\_ -> state)
