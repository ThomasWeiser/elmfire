/* @flow */
/* global Elm, Firebase, F2, F3, F4 */

var _ThomasWeiser$elmfire$Native_ElmFire_Auth = function () {

  var ElmFire = _ThomasWeiser$elmfire$Native_ElmFire;
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
    return _elm_lang$core$Native_Scheduler .fail (fbAuthTaskError (fbAuthError));
  }

  function exceptionAuthTaskFail (exception) {
    return _elm_lang$core$Native_Scheduler.fail (authError2elm ('OtherAuthenticationError', exception.toString ()));
  }

  function auth2elm (fbAuth) {
    var specifics = {};
    if (fbAuth.hasOwnProperty (fbAuth.provider)) {
      specifics = fbAuth [fbAuth.provider];
    }
    return {
      uid: fbAuth .uid,
      provider: fbAuth .provider,
      token: fbAuth .token,
      expires: _elm_lang$core$Date$fromTime (fbAuth .expires * _elm_lang$core$Date$second),
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
    _elm_lang$core$Native_Scheduler .rawSpawn (this.createResponseTask (maybeAuth2elm (fbAuth)));
  }

  function subscribeAuth (createResponseTask, location) {
    return _elm_lang$core$Native_Scheduler .nativeBinding (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var context = { createResponseTask: createResponseTask };
        try { ref.onAuth (onAuthCallback, context); }
        catch (exception) {
          callback (exceptionAuthTaskFail (exception));
          return;
        }
        callback (_elm_lang$core$Native_Scheduler.succeed (_elm_lang$core$Native_Utils.Tuple0));
      }
    });
  }

  function unsubscribeAuth (location) {
    return _elm_lang$core$Native_Scheduler .nativeBinding (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        try {
          ref.offAuth (onAuthCallback);
        }
        catch (exception) {
          callback (exceptionAuthTaskFail (exception));
          return;
        }
        callback (_elm_lang$core$Native_Scheduler.succeed (_elm_lang$core$Native_Utils.Tuple0));
      }
    });
  }

  function getAuth (location) {
    return _elm_lang$core$Native_Scheduler .nativeBinding (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var auth;
        try { auth = ref .getAuth (); }
        catch (exception) {
          callback (exceptionAuthTaskFail (exception));
          return;
        }
        callback (_elm_lang$core$Native_Scheduler.succeed (maybeAuth2elm (auth)));
      }
    });
  }

  function authenticate (location, listOfOptions, id) {
    return _elm_lang$core$Native_Scheduler .nativeBinding (function (callback) {
      getRef (location, callback);
      var ref = firebase.auth();
      if (ref) {
        var options = toObject (listOfOptions);
        var onComplete = function (err, auth) {
          if (err) {
            callback (fbAuthTaskFail (err));
          } else {
            callback (_elm_lang$core$Native_Scheduler.succeed (auth2elm (auth)));
          }
        };
        try {
          switch (id.ctor) {
            case 'Anonymous':
              ref.authAnonymously (onComplete, options);
              break;
            case 'Password':
              ref.signInWithEmailAndPassword (id._0, id._1) .then (onComplete);
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
        catch (exception) { callback (exceptionAuthTaskFail (exception)); }
      }
    });
  }

  function unauthenticate (location) {
    return _elm_lang$core$Native_Scheduler .nativeBinding (function (callback) {
      var ref = getRef (location);
      if (ref) {
        try { ref.unauth (); }
        catch (exception) {
          callback (exceptionAuthTaskFail (exception));
          return;
        }
        callback (_elm_lang$core$Native_Scheduler.succeed (_elm_lang$core$Native_Utils.Tuple0));
      }
    });
  }

  function userOperation (location, op) {
    return _elm_lang$core$Native_Scheduler .nativeBinding (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var onComplete = function (err, res) {
          if (err) {
            callback (fbAuthTaskFail (err));
          } else {
            callback (_elm_lang$core$Native_Scheduler.succeed (asMaybe (res && res.uid)));
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
        catch (exception) { callback (exceptionAuthTaskFail (exception)); }
      }
    });
  }

  return {
      subscribeAuth: F2 (subscribeAuth)
    ,	unsubscribeAuth: unsubscribeAuth
    ,	getAuth: getAuth
    , authenticate: F3 (authenticate)
    , unauthenticate: unauthenticate
    , userOperation: F2 (userOperation)
  };
} ();
