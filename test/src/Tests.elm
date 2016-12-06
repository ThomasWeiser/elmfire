{- A Sketch of a Test App for ElmFire

   A given sequence of tasks is run on the Firebase API.

   This is work in progress.
-}


module Main exposing (..)

import String
import List
import Time
import Task exposing (Task)
import Json.Encode as JE
import Json.Decode as JD exposing ((:=))
import Html exposing (Html, div, span, text, a, h1, h2)
import Html.Attributes exposing (href, target, class)
import TaskTest exposing (..)
import ElmFire exposing (..)
import ElmFire.Auth as Auth


-------------------------------------------------------------------------------
-- Use this test Firebase. The tests below rely on some settings in this Firebase.
-- Individual executions of this test suite use independent branches in this Firebase.


url : String
url =
    "https://elmfiretest.firebaseio.com/"


dino : Location
dino =
    fromUrl url |> sub "dinosaur-facts"



-------------------------------------------------------------------------------


isNothing : Maybe a -> Bool
isNothing x =
    case x of
        Just _ ->
            False

        Nothing ->
            True


isJust : Maybe a -> Bool
isJust =
    not << isNothing


isLocationError : Error -> Bool
isLocationError err =
    err.tag == LocationError


isPermissionError : Error -> Bool
isPermissionError err =
    err.tag == PermissionError


action1 : Maybe JE.Value -> Action
action1 maybeValue =
    case maybeValue of
        Just value ->
            case JD.decodeValue JD.string value of
                Ok str ->
                    Set (JE.string <| str ++ "!")

                _ ->
                    Remove

        _ ->
            Abort


type alias PrintableSnapshot =
    { subscription : Subscription
    , key : String
    , existing : Bool
    , value : JE.Value
    , prevKey : Maybe String
    , priority : Priority
    }


printableSnapshot : Snapshot -> PrintableSnapshot
printableSnapshot snap =
    { subscription = snap.subscription
    , key = snap.key
    , existing = snap.existing
    , value = snap.value
    , prevKey = snap.prevKey
    , priority = snap.priority
    }


type Response
    = NoResponse
    | Data PrintableSnapshot
    | Canceled Cancellation


test1 =
    -- Start tests by opening a path and creating a reference for it ------------
    sequence "Test Sequence"
        (test "open" (open (fromUrl url |> sub "test" |> push |> push))
            |>> succeeds
            |>> meets "url of opened ref starts with base-url" (\ref -> url `String.startsWith` toUrl ref)
            |>+ \ref ->
                    -- Connection state tests ---------------------------------------------------
                    createReporter "Metadata results"
                        |>+ \reporterConnected ->
                                test "subscribe to connection state changes"
                                    (subscribeConnected
                                        ((\state -> "connected: " ++ toString state) >> reporterConnected)
                                        (location ref)
                                    )
                                    |>> succeeds
                                    |>- test "subscribe to serverTimeOffset changes"
                                            (subscribeServerTimeOffset
                                                ((\offset -> "serverTimeOffset: " ++ toString offset) >> reporterConnected)
                                                (location ref)
                                            )
                                    |>> succeeds
                                    -- Create a new path in the Firebase for this test run ----------------------
                                    |>-
                                        test "setWithPriority" (setWithPriority (JE.string "Hello") (NumberPriority 42) (location ref))
                                    |>> meets "set returned same ref" (\refReturned -> toUrl refReturned == toUrl ref)
                                    |>> map location
                                    |>+ \loc ->
                                            test "once valueChanged (at child)" (once (valueChanged noOrder) loc)
                                                |>> printMapResult printableSnapshot
                                                |>> meets "once returned same key" (\snapshot -> snapshot.key == key ref)
                                                |>- test "onDisconnectSet"
                                                        (onDisconnectSet (JE.string "disconnected") (loc |> parent |> sub "onlineState"))
                                                |>> printResult
                                                |>> succeeds
                                                |>- test "onDisconnectSet has not written yet"
                                                        (once (valueChanged noOrder) (loc |> parent |> sub "onlineState"))
                                                |>> meets "value is not existing"
                                                        (\snapshot -> not snapshot.existing)
                                                |>> meets "value is null"
                                                        (\snapshot -> snapshot.value == JE.null)
                                                |>- test "go offline" goOffline
                                                |>> succeeds
                                                |>- test "go online" goOnline
                                                |>> succeeds
                                                |>- test "onDisconnectSet has now written the value"
                                                        (once (valueChanged noOrder) (loc |> parent |> sub "onlineState"))
                                                |>> meets "value is written"
                                                        (\snapshot -> snapshot.value == JE.string "disconnected")
                                                -- Test updating ------------------------------------------------------------
                                                |>-
                                                    test "deep update"
                                                        (update
                                                            (JE.object [ ( "a/b", JE.string "AB" ) ])
                                                            (loc |> parent)
                                                            `Task.andThen`
                                                                \_ ->
                                                                    once
                                                                        (valueChanged noOrder)
                                                                        (loc |> parent |> sub "a/b")
                                                        )
                                                |>> meets "updated value ok"
                                                        (\snapshot -> snapshot.value == JE.string "AB")
                                                -- User management tests ----------------------------------------------------
                                                |>-
                                                    test "generate a test email address from the resulting key string"
                                                        (Task.succeed <| (key ref) ++ "@b.com")
                                                |>> printResult
                                                |>+ \email ->
                                                        test "create user" (Auth.userOperation loc (Auth.createUser email "pw1"))
                                                            |>> printResult
                                                            |>> meets "returns a uid" isJust
                                                            |>- test "change password with wrong old password" (Auth.userOperation loc (Auth.changePassword email "wrong" "pw2"))
                                                            |>> errorMeets "reports AuthError InvalidPassword"
                                                                    (\err -> err.tag == AuthError InvalidPassword)
                                                            |>- test "change password" (Auth.userOperation loc (Auth.changePassword email "pw1" "pw2"))
                                                            |>> printResult
                                                            |>> succeeds
                                                            |>- test "change email" (Auth.userOperation loc (Auth.changeEmail email "pw2" ("2" ++ email)))
                                                            |>> succeeds
                                                            {- Don't run this test by default (Firebase sends an nonaddressable email each time)
                                                               |>- test  "reset password" (Auth.userOperation loc (Auth.resetPassword ("2" ++ email)))
                                                               |>> succeeds
                                                            -}
                                                            |>-
                                                                test "remove nonexistent user" (Auth.userOperation loc (Auth.removeUser (email) "pw2"))
                                                            |>> errorMeets "reports AuthError InvalidUser"
                                                                    (\err -> err.tag == AuthError InvalidUser)
                                                            |>- test "remove user" (Auth.userOperation loc (Auth.removeUser ("2" ++ email) "pw2"))
                                                            |>> succeeds
                                                            -- Authentication tests -----------------------------------------------------
                                                            |>-
                                                                createReporter "authSubscription results"
                                                            |>+ \reporterAuth ->
                                                                    test "subscribe to authentication changes"
                                                                        (Auth.subscribeAuth
                                                                            reporterAuth
                                                                            loc
                                                                        )
                                                                        |>> succeeds
                                                                        |>- test "unauthenticate" (Auth.unauthenticate loc)
                                                                        |>> printResult
                                                                        |>> succeeds
                                                                        |>- test "getAuth while not authenticated" (Auth.getAuth loc)
                                                                        |>> printResult
                                                                        |>> equals "getAuth returns Nothing" Nothing
                                                                        |>- test "getAuth with invalid location" (Auth.getAuth (loc |> root |> parent))
                                                                        |>> errorMeets "reports LocationError" isLocationError
                                                                        |>- test "auth anonymously"
                                                                                (Auth.authenticate loc [ Auth.rememberNone ] Auth.asAnonymous)
                                                                        |>> printResult
                                                                        |>- test "getAuth after authentication" (Auth.getAuth loc)
                                                                        |>> printResult
                                                                        |>> meets "getAuth returns an anonymous provider"
                                                                                (\maybeAuth ->
                                                                                    case maybeAuth of
                                                                                        Just auth ->
                                                                                            auth.provider == "anonymous"

                                                                                        _ ->
                                                                                            False
                                                                                )
                                                                        |>- test "re-auth with wrong password"
                                                                                (Auth.unauthenticate loc
                                                                                    `Task.andThen`
                                                                                        \_ ->
                                                                                            Auth.authenticate loc [ Auth.rememberNone ] (Auth.withPassword "a@b.com" "bad")
                                                                                )
                                                                        |>> errorMeets "reports AuthError InvalidPassword"
                                                                                (\err -> err.tag == AuthError InvalidPassword)
                                                                        |>- test "re-auth with right password"
                                                                                (Auth.unauthenticate loc
                                                                                    `Task.andThen`
                                                                                        \_ ->
                                                                                            Auth.authenticate loc [ Auth.rememberNone ] (Auth.withPassword "a@b.com" "good")
                                                                                )
                                                                        |>> printResult
                                                                        |>> meets "provider-specifics contain the given email address"
                                                                                (\auth -> JD.decodeValue ("email" := JD.string) auth.specifics == Ok "a@b.com")
                                                                        -- Test reading and writing (except complex queries) ------------------------
                                                                        |>-
                                                                            test "once valueChanged (at child)" (once (valueChanged noOrder) loc)
                                                                        |>> printMapResult printableSnapshot
                                                                        |>> meets "once returned same key" (\snapshot -> snapshot.key == key ref)
                                                                        |>> meets "once returned right value" (\snapshot -> snapshot.value == JE.string "Hello")
                                                                        |>> meets "once returned right prevKey" (\snapshot -> snapshot.prevKey == Nothing)
                                                                        |>> meets "once returned right priority" (\snapshot -> snapshot.priority == NumberPriority 42)
                                                                        |>> map exportValue
                                                                        |>> meets "export contains right value"
                                                                                (\ex -> JD.decodeValue (".value" := JD.string) ex == Ok "Hello")
                                                                        |>> meets "export contains right priority"
                                                                                (\ex -> JD.decodeValue (".priority" := JD.int) ex == Ok 42)
                                                                        |>- createReporter "subscription results"
                                                                        |>+ \reporter1 ->
                                                                                test "subscribe child added (at parent)"
                                                                                    (subscribe
                                                                                        (printableSnapshot >> Data >> reporter1)
                                                                                        (Canceled >> reporter1)
                                                                                        (childAdded noOrder)
                                                                                        (parent loc)
                                                                                    )
                                                                                    |>> succeeds
                                                                                    |>> printResult
                                                                                    |>- test "sleep 1s" (Task.sleep (1 * Time.second))
                                                                                    |>- test "set child with serverTimeStamp" (set serverTimeStamp (loc |> parent |> sub "server timestamp"))
                                                                                    |>- test "set another child" (set (JE.string "Elmers") (loc |> parent |> push))
                                                                                    |>> map key
                                                                                    |>> printResult
                                                                                    |>+ \key ->
                                                                                            test "transaction on that child"
                                                                                                (transaction action1 (loc |> parent |> sub key) True)
                                                                                                |>> meets "committed and returned changed value"
                                                                                                        (\( committed, snapshot ) ->
                                                                                                            committed && snapshot.value == JE.string "Elmers!"
                                                                                                        )
                                                                                                |>> printMapResult (snd >> printableSnapshot)
                                                                                                |>- test "once valueChanged at non-existing location"
                                                                                                        (once (valueChanged noOrder) (sub "_non_existing_key_" loc))
                                                                                                |>> meets "returns non-existing" (\snapshot -> not snapshot.existing)
                                                                                                |>- test "set without permission"
                                                                                                        (set (JE.null) (fromUrl url |> sub "unaccessible"))
                                                                                                |>> printResult
                                                                                                |>> fails
                                                                                                |>> errorMeets "reports PermissionError" isPermissionError
                                                                                                |>- clear
                                                                                                |>- test "once without permission"
                                                                                                        (once (valueChanged noOrder) (fromUrl url |> sub "unaccessible"))
                                                                                                |>> printResult
                                                                                                |>> fails
                                                                                                |>> errorMeets "reports PermissionError" isPermissionError
                                                                                                |>- clear
                                                                                                |>- createReporter "subscription without permission results"
                                                                                                |>+ \reporter2 ->
                                                                                                        test "subscribe without permission"
                                                                                                            (subscribe
                                                                                                                (printableSnapshot >> Data >> reporter2)
                                                                                                                (Canceled >> reporter2)
                                                                                                                (valueChanged noOrder)
                                                                                                                (fromUrl url |> sub "unaccessible")
                                                                                                            )
                                                                                                            |>> printResult
                                                                                                            |>- clear
                                                                                                            |>- test "transaction without permission"
                                                                                                                    (transaction action1 (fromUrl url |> sub "unaccessible") True)
                                                                                                            |>> meets "not committed" (\( committed, _ ) -> not committed)
                                                                                                            |>- clear
                                                                                                            |>- test "open root's parent" (open (fromUrl url |> root |> parent))
                                                                                                            |>> printResult
                                                                                                            |>> errorMeets "reports LocationError" isLocationError
                                                                                                            |>- clear
                                                                                                            |>- test "open an invalid URL" (open (fromUrl "not-a-url"))
                                                                                                            |>> printResult
                                                                                                            |>> errorMeets "reports LocationError" isLocationError
                                                                                                            |>- clear
                                                                                                            |>- test "subscribe with invalid URL"
                                                                                                                    (subscribe
                                                                                                                        (always Task.succeed ())
                                                                                                                        (always Task.succeed ())
                                                                                                                        (valueChanged noOrder)
                                                                                                                        (fromUrl "not-a-url")
                                                                                                                    )
                                                                                                            |>> printResult
                                                                                                            |>> fails
                                                                                                            |>> errorMeets "reports LocationError" isLocationError
                                                                                                            |>- test "transaction with invalid URL"
                                                                                                                    (transaction action1 (fromUrl "not-a-url") True)
                                                                                                            |>> printResult
                                                                                                            |>> fails
                                                                                                            |>> errorMeets "reports LocationError" isLocationError
                                                                                                            |>- clear
                                                                                                            -- Test complex queries, using the dino example data from Firebase docs -----
                                                                                                            |>-
                                                                                                                test "dino test data" (once (valueChanged noOrder) dino)
                                                                                                            |>> map (.value >> JE.encode 2)
                                                                                                            |>> printString
                                                                                                            |>- test "toSnapshotList" (once (valueChanged noOrder) (dino |> sub "scores"))
                                                                                                            |>> map (toSnapshotList >> List.map printableSnapshot)
                                                                                                            |>> printResult
                                                                                                            |>- test "dinos, ordered by child 'height', limited to last 2"
                                                                                                                    (once
                                                                                                                        (valueChanged (orderByChild "height" noRange (limitToLast 2)))
                                                                                                                        (dino |> sub "dinosaurs")
                                                                                                                    )
                                                                                                            |>> map (toValueList >> JE.list >> JE.encode 2)
                                                                                                            |>> printString
                                                                                                            |>- createReporter "subscription results: dino scores, ordered by value, limited to first 3"
                                                                                                            |>+ \reporterDino ->
                                                                                                                    test "subscribe dino scores, ordered by value, limited to first 3"
                                                                                                                        (subscribe
                                                                                                                            (printableSnapshot >> Data >> reporterDino)
                                                                                                                            (Canceled >> reporterDino)
                                                                                                                            (childAdded (orderByValue noRange (limitToFirst 3)))
                                                                                                                            (dino |> sub "scores")
                                                                                                                        )
                                                                                                                        |>> printResult
                                                                                                                        |>- test "dinos, ordered by key, limited to first 2"
                                                                                                                                (once
                                                                                                                                    (valueChanged (orderByKey noRange (limitToFirst 2)))
                                                                                                                                    (dino |> sub "dinosaurs")
                                                                                                                                )
                                                                                                                        |>> map (toKeyList >> String.join " ")
                                                                                                                        |>> printString
                                                                                                                        |>- test "order by priority"
                                                                                                                                (once (valueChanged (orderByPriority noRange noLimit)) (parent loc))
                                                                                                                        |>> map (toSnapshotList >> List.map .priority)
                                                                                                                        |>> printResult
                                                                                                                        |>- test "order by priority, start at priority number 10"
                                                                                                                                (once
                                                                                                                                    (valueChanged
                                                                                                                                        (orderByPriority
                                                                                                                                            (startAt ( NumberPriority 10, Nothing ))
                                                                                                                                            noLimit
                                                                                                                                        )
                                                                                                                                    )
                                                                                                                                    (parent loc)
                                                                                                                                )
                                                                                                                        |>> map (toSnapshotList >> List.map .priority)
                                                                                                                        |>> printResult
                                                                                                                        |>- test "order by priority, end at priority number 10"
                                                                                                                                (once
                                                                                                                                    (valueChanged
                                                                                                                                        (orderByPriority
                                                                                                                                            (endAt ( NumberPriority 10, Nothing ))
                                                                                                                                            noLimit
                                                                                                                                        )
                                                                                                                                    )
                                                                                                                                    (parent loc)
                                                                                                                                )
                                                                                                                        |>> map (toSnapshotList >> List.map .priority)
                                                                                                                        |>> printResult
                                                                                                                        |>- test "order by child 'height', start at value 3, end at value 10"
                                                                                                                                (once
                                                                                                                                    (valueChanged
                                                                                                                                        (orderByChild "height"
                                                                                                                                            (range (JE.int 3) (JE.int 10))
                                                                                                                                            noLimit
                                                                                                                                        )
                                                                                                                                    )
                                                                                                                                    (dino |> sub "dinosaurs")
                                                                                                                                )
                                                                                                                        |>> map (toPairList >> JE.object >> JE.encode 2)
                                                                                                                        |>> printString
                                                                                                                        |>- test "dinos, ordered by key, starting with letter 'l'"
                                                                                                                                (once
                                                                                                                                    (valueChanged
                                                                                                                                        (orderByKey (range "l" "l~") noLimit)
                                                                                                                                    )
                                                                                                                                    (dino |> sub "dinosaurs")
                                                                                                                                )
                                                                                                                        |>> map (toKeyList >> String.join " ")
                                                                                                                        |>> printString
                                                                                                                        |>- test "dinos, ordered by prioriy, start at NoPriority and key 's'"
                                                                                                                                (once
                                                                                                                                    (valueChanged
                                                                                                                                        (orderByPriority
                                                                                                                                            (startAt ( NoPriority, (Just "s") ))
                                                                                                                                            noLimit
                                                                                                                                        )
                                                                                                                                    )
                                                                                                                                    (dino |> sub "dinosaurs")
                                                                                                                                )
                                                                                                                        |>> map (toKeyList >> String.join " ")
                                                                                                                        |>> printString
                                                                                                                        |>- test "end of test sequence" (Task.succeed ())
                                                                                                                        |>- clear
        )


port runTasks : Task Error ()
port runTasks =
    runTest test1


view : Html -> Html
view testDisplay =
    div []
        [ h1 [] [ text "ElmFire Test" ]
        , div [] [ a [ href url, target "_blank" ] [ text url ] ]
        , h2 [] [ text "Test Report:" ]
        , testDisplay
        ]


main : Signal Html
main =
    Signal.map view testDisplay
