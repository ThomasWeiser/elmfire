module ElmFire.Auth
  ( Authentication
  , getAuth, subscribeAuth, unsubscribeAuth
  , Identification
  , authenticate, unauthenticate
  , asAnonymous, withPassword, withOAuthPopup, withOAuthRedirect
  , withOAuthAccessToken, withOAuthCredentials, withCustomToken
  , Options
  , rememberDefault, rememberSessionOnly, rememberNone
  , UserOperation
  , createUser, removeUser, changeEmail, changePassword, resetPassword
  , userOperation
  ) where

{-| Elm bindings to Firebase Authentication.

Note that all tasks in this module refer to a entire Firebase, not a specific path within a Firebase.
Therefore, only the root of the `Location` parameter is relevant.

# Getting Authentication Status
@docs Authentication, getAuth, subscribeAuth, unsubscribeAuth

# Perform Authentication
@docs Identification, authenticate, unauthenticate,
asAnonymous, withPassword, withOAuthPopup, withOAuthRedirect,
withOAuthAccessToken, withOAuthCredentials, withCustomToken

# Options
@docs Options, rememberDefault, rememberSessionOnly, rememberNone

# User Management
@docs UserOperation, userOperation,
createUser, removeUser, changeEmail, changePassword, resetPassword
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

asAnonymous : Identification
asAnonymous = Anonymous

withPassword : String -> String -> Identification
withPassword = Password

withOAuthPopup : String -> Identification
withOAuthPopup = OAuthPopup

withOAuthRedirect : String -> Identification
withOAuthRedirect = OAuthRedirect

withOAuthAccessToken : String -> String -> Identification
withOAuthAccessToken = OAuthAccessToken

withOAuthCredentials : String -> List (String, String) -> Identification
withOAuthCredentials = OAuthCredentials

withCustomToken : String -> Identification
withCustomToken = CustomToken

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

{-| UserOperation: Create a user identity.
Parameter: email password -}
createUser : String -> String -> UserOperation
createUser = CreateUser

{-| UserOperation: Remove a user identity.
Parameter: email password -}
removeUser : String -> String -> UserOperation
removeUser = RemoveUser

{-| UserOperation: Change the email address of a user identity.
Parameter: oldEmail password newEmail -}
changeEmail : String -> String -> String -> UserOperation
changeEmail = ChangeEmail

{-| UserOperation: Change the password of a user identity.
Parameter: email oldPassword newPassword -}
changePassword : String -> String -> String -> UserOperation
changePassword = ChangePassword

{-| UserOperation: Initiate a password reset. Firebase will send an appropriate email to the account owner.
Parameter: email -}
resetPassword : String -> UserOperation
resetPassword = ResetPassword

{-| Perform a user management operation at a Firebase

Operation `createUser` returns a `Just uid` on success,
all other operations return `Nothing` on success.
-}
userOperation : Location
             -> UserOperation
             -> Task Error (Maybe String)
userOperation = Native.ElmFire.Auth.userOperation
