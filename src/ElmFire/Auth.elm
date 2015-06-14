module ElmFire.Auth
  ( Authentication
  , Identification (..)
  , Options, rememberDefault, rememberSessionOnly, rememberNone
  , UserOperation (..)
  , getAuth, subscribeAuth, unsubscribeAuth
  , authenticate, unauthenticate
  , userOperation
  ) where

{-| Elm bindings to Firebase Authentication.

Note that all tasks in this module refer to a entire Firebase, not a specific path within a Firebase.
Therefore, only the root of the `Location` parameter is relevant.

# Getting Authentication Status
@docs Authentication, getAuth, subscribeAuth, unsubscribeAuth

# Perform Authentication
@docs Identification, authenticate, unauthenticate,
Options, rememberDefault, rememberSessionOnly, rememberNone

# User Management
@docs UserOperation, userOperation
-}

import Native.Firebase
import Native.ElmFire.Auth
import ElmFire exposing (Location, Reference, Error)

import Date exposing (Date)
import Json.Encode as JE
import Task exposing (Task)

{-| Authentication data. See Firebase doc for details. -}
type alias Authentication =
  { uid: String
  , provider: String
  , token: String
  , expires: Date
  , auth: JE.Value
  , specifics: JE.Value
  }

{-| Subscribe to changes to the client's authentication state -}
subscribeAuth : (Maybe Authentication -> Task x a) -> Location -> Task Error ()
subscribeAuth = Native.ElmFire.Auth.subscribeAuth

{-| Quit subscription to authentication state -}
unsubscribeAuth : Location -> Task Error ()
unsubscribeAuth = Native.ElmFire.Auth.unsubscribeAuth

{-| Retrieve the current authentication state of the client -}
getAuth : Location -> Task Error (Maybe Authentication)
getAuth = Native.ElmFire.Auth.getAuth

{-| Identification options to authenticate at a Firebase -}
type Identification
  = Anonymous
  | Password String String
  | OAuthPopup String
  | OAuthRedirect String
  | OAuthAccessToken String String
  | OAuthCredentials String (List (String, String))
  | CustomToken String

{-| Optional authentication parameter

All providers allow option `remember` to specify the presistency of authentication.

Specific provider may accept additional options. See firebase docs.
-}
type alias Options = List (String, String)

{- Option for default persistence:
Sessions are persisted for as long as it is configured in the Firebase's dashboard.
-}
rememberDefault = ("remember", "default")

{- Option for session only persistence:

Persistence is limited to the lifetime of the current window.
-}
rememberSessionOnly = ("remember", "sessionOnly")

{- Option for no persistence:

No persistent authentication data is used. End authentication as soon as the page is closed.
-}
rememberNone = ("remember", "none")

{-| Authenticate client at a Firebase -}
authenticate : Location
            -> Options
            -> Identification
            -> Task Error Authentication
authenticate = Native.ElmFire.Auth.authenticate

{-| Unauthenticate client at a Firebase -}
unauthenticate : Location -> Task Error ()
unauthenticate = Native.ElmFire.Auth.unauthenticate

{-| Specification of a user management operation -}
type UserOperation
  = CreateUser String String            -- email password
  | RemoveUser String String            -- email password
  | ChangeEmail String String String    -- email password newEmail
  | ChangePassword String String String -- email password newPassword
  | ResetPassword String                -- email

{-| Perform a user management operation at a Firebase

Only `CreateUser` returns a `Just uid` on success,
all other operations return `Nothing`.
-}
userOperation : Location
             -> UserOperation
             -> Task Error (Maybe String)
userOperation = Native.ElmFire.Auth.userOperation
