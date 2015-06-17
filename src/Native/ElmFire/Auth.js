/* @flow */
/* global Elm, Firebase, F2, F3, F4 */

Elm.Native.ElmFire = Elm.Native.ElmFire || {};
Elm.Native.ElmFire.Auth = {};
Elm.Native.ElmFire.Auth.make = function (localRuntime) {
  "use strict";

  localRuntime.Native = localRuntime.Native || {};
  localRuntime.Native.ElmFire = localRuntime.Native.ElmFire || {};
  localRuntime.Native.ElmFire.Auth = localRuntime.Native.ElmFire.Auth || {};
  if (localRuntime.Native.ElmFire.Auth.values) {
    return localRuntime.Native.ElmFire.Auth.values;
  }

  var Utils = Elm.Native.Utils.make (localRuntime);
  var Task = Elm.Native.Task.make (localRuntime);

  var Date = Elm.Date.make (localRuntime);
  var Time = Elm.Time.make (localRuntime);

  var ElmFire = Elm.Native.ElmFire.make (localRuntime);
  var asMaybe = ElmFire.asMaybe;
  var getRef = ElmFire.getRef;
  var pleaseReportThis = ElmFire.pleaseReportThis;

	function toObject (listOfPairs)
 {
   var obj = {};
   while (listOfPairs.ctor !== '[]')
   {
     var pair = listOfPairs._0;
     obj [pair._0] = pair._1;
     listOfPairs = listOfPairs._1;
   }
   return obj;
 }

  function authError2elm (tag, description) {
    return {
      _: {},
      tag: { ctor: 'AuthError', _0: { ctor: tag } },
      description: description
    };
  }

  var fbAuthErrorMap = {
    AUTHENTICATION_DISABLED: 'AuthenticationDisabled',
    EMAIL_TAKEN: 'EmailTaken',
    INVALID_ARGUMENTS: 'InvalidArguments',
    INVALID_CONFIGURATION: 'InvalidConfiguration',
    INVALID_CREDENTIALS: 'InvalidCredentials',
    INVALID_EMAIL: 'InvalidEmail',
    INVALID_ORIGIN: 'InvalidOrigin',
    INVALID_PASSWORD: 'InvalidPassword',
    INVALID_PROVIDER: 'InvalidProvider',
    INVALID_TOKEN: 'InvalidToken',
    INVALID_USER: 'InvalidUser',
    NETWORK_ERROR: 'NetworkError',
    PROVIDER_ERROR: 'ProviderError',
    TRANSPORT_UNAVAILABLE: 'TransportUnavailable',
    UNKNOWN_ERROR: 'UnknownError',
    USER_CANCELLED: 'UserCancelled',
    USER_DENIED: 'UserDenied'
  };

  function fbAuthTaskError (fbAuthError) {
    var tag = fbAuthErrorMap [fbAuthError.code];
    if (! tag) {
      tag = 'OtherAuthenticationError';
    }
    return authError2elm (tag, fbAuthError .toString ());
  }

  function fbAuthTaskFail (fbAuthError) {
    return Task .fail (fbAuthTaskError (fbAuthError));
  }

  function exAuthTaskFail (exception) {
    return Task.fail (authError2elm ('OtherAuthenticationError', exception.toString ()));
  }

  function auth2elm (fbAuth) {
    var specifics = {};
    if (fbAuth.hasOwnProperty (fbAuth.provider)) {
      specifics = fbAuth [fbAuth.provider];
    }
    return {
      _: {},
      uid: fbAuth .uid,
      provider: fbAuth .provider,
      token: fbAuth .token,
      expires: Date .fromTime (fbAuth .expires * Time .second),
      auth: JSON .parse (JSON .stringify (fbAuth .auth)),
      specifics: specifics
    };
  }

  function maybeAuth2elm (fbAuth) {
    if (fbAuth) {
      return { ctor: 'Just', _0: auth2elm (fbAuth) };
    } else {
      return { ctor: 'Nothing' };
    }
  }

  function onAuthCallback (fbAuth) {
    Task .perform (this.createResponseTask (maybeAuth2elm (fbAuth)));
  }

  function subscribeAuth (createResponseTask, location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var context = { createResponseTask: createResponseTask };
        try { ref.onAuth (onAuthCallback, context); }
        catch (exception) {
          callback (exAuthTaskFail (exception));
          return;
        }
        callback (Task.succeed (Utils.Tuple0));
      }
    });
  }

  function unsubscribeAuth (location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        try {
          ref.offAuth (onAuthCallback);
        }
        catch (exception) {
          callback (exAuthTaskFail (exception));
          return;
        }
        callback (Task.succeed (Utils.Tuple0));
      }
    });
  }

  function getAuth (location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var auth;
        try { auth = ref .getAuth (); }
        catch (exception) {
          callback (exAuthTaskFail (exception));
          return;
        }
        callback (Task.succeed (maybeAuth2elm (auth)));
      }
    });
  }

  function authenticate (location, listOfOptions, id) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var options = toObject (listOfOptions);
        var onComplete = function (err, auth) {
          if (err) {
            callback (fbAuthTaskFail (err));
          } else {
            callback (Task.succeed (auth2elm (auth)));
          }
        };
        try {
          switch (id.ctor) {
            case 'Anonymous':
              ref.authAnonymously (onComplete, options);
              break;
            case 'Password':
              ref.authWithPassword ({ email: id._0, password: id._1 }, onComplete, options);
              break;
            case 'OAuthPopup':
              ref.authWithOAuthPopup (id._0, onComplete, options);
              break;
            case 'OAuthRedirect':
              ref.authWithOAuthRedirect (id._0, onComplete, options);
              break;
            case 'OAuthAccessToken':
              ref.authWithOAuthToken (id._0, id._1, onComplete, options);
              break;
            case 'OAuthCredentials':
              ref.authWithOAuthToken (id._0, toObject (id._1), onComplete, options);
              break;
            case 'CustomToken':
              ref.authWithCustomToken (id._0, onComplete, options);
              break;
            default: throw ('Bad identification tag.' + pleaseReportThis);
          }
        }
        catch (exception) { callback (exAuthTaskFail (exception)); }
      }
    });
  }

  function unauthenticate (location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location);
      if (ref) {
        try { ref.unauth (); }
        catch (exception) {
          callback (exAuthTaskFail (exception));
          return;
        }
        callback (Task.succeed (Utils.Tuple0));
      }
    });
  }

  function userOperation (location, op) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var onComplete = function (err, res) {
          if (err) {
            callback (fbAuthTaskFail (err));
          } else {
            callback (Task.succeed (asMaybe (res && res.uid)));
          }
        };
        try {
          switch (op.ctor) {
            case 'CreateUser':
              ref.createUser ({ email: op._0, password: op._1 }, onComplete);
              break;
            case 'RemoveUser':
              ref.removeUser ({ email: op._0, password: op._1 }, onComplete);
              break;
            case 'ChangeEmail':
              ref.changeEmail ({ oldEmail: op._0, password: op._1, newEmail: op._2 }, onComplete);
              break;
            case 'ChangePassword':
              ref.changePassword ({ email: op._0, oldPassword: op._1, newPassword: op._2 }, onComplete);
              break;
            case 'ResetPassword':
              ref.resetPassword ({ email: op._0 }, onComplete);
              break;
            default: throw ('Bad user operation tag.' + pleaseReportThis);
          }
        }
        catch (exception) { callback (exAuthTaskFail (exception)); }
      }
    });
  }

  return localRuntime.Native.ElmFire.Auth.values =
  { 	subscribeAuth: F2 (subscribeAuth)
    ,	unsubscribeAuth: unsubscribeAuth
    ,	getAuth: getAuth
    , authenticate: F3 (authenticate)
    , unauthenticate: unauthenticate
    , userOperation: F2 (userOperation)
  };
};
