module EffectManager exposing (..)

import Dict exposing (Dict)


{- -}


type alias CurrentSubs spec tagger handle =
    Dict spec ( List tagger, handle )


type alias RequestedSubs spec tagger =
    Dict spec (List tagger)


type Alteration spec tagger handle
    = Create spec (List tagger)
    | Update spec handle (List tagger)
    | Delete spec handle


requestedSubsFromList :
    (mySub -> ( comparableSpec, tagger ))
    -> List mySub
    -> RequestedSubs comparableSpec tagger
requestedSubsFromList map list =
    let
        -- add : mySub  -> Dict comparableSpec (List tagger) -> Dict comparableSpec (List tagger)
        add mySub dictAccu =
            let
                ( spec, tagger ) =
                    map mySub
            in
                Dict.update
                    spec
                    (\maybeVal ->
                        Just <|
                            tagger
                                :: Maybe.withDefault [] maybeVal
                    )
                    dictAccu
    in
        List.foldl add Dict.empty list


alterations :
    RequestedSubs comparableSpec tagger
    -> CurrentSubs comparableSpec tagger handle
    -> List (Alteration comparableSpec tagger handle)
alterations requestedSubs currentSubs =
    let
        create spec requestedTaggers list =
            Create spec requestedTaggers :: list

        update spec requestedTaggers ( currentTaggers, handle ) list =
            Update spec handle requestedTaggers :: list

        delete spec ( currentTaggers, handle ) list =
            Delete spec handle :: list
    in
        Dict.merge
            create
            update
            delete
            requestedSubs
            currentSubs
            []


emptySubs : CurrentSubs comparableSpec tagger handle
emptySubs =
    Dict.empty


insertSub :
    comparableSpec
    -> List tagger
    -> handle
    -> CurrentSubs comparableSpec tagger handle
    -> CurrentSubs comparableSpec tagger handle
insertSub spec taggers handle =
    Dict.insert spec ( taggers, handle )


removeSub :
    comparableSpec
    -> CurrentSubs comparableSpec tagger handle
    -> CurrentSubs comparableSpec tagger handle
removeSub spec =
    Dict.remove spec


getSub :
    comparableSpec
    -> CurrentSubs comparableSpec tagger handle
    -> Maybe ( List tagger, handle )
getSub spec currentSubs =
    Dict.get spec currentSubs
