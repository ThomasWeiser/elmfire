/* @flow */
/* global Elm, Firebase, F2, F3, F4 */

Elm.Native.ElmFire = {};
Elm.Native.ElmFire.make = function (localRuntime) {
  "use strict";

  localRuntime.Native = localRuntime.Native || {};
  localRuntime.Native.ElmFire = localRuntime.Native.ElmFire || {};
  if (localRuntime.Native.ElmFire.values) {
    return localRuntime.Native.ElmFire.values;
  }

  var Utils = Elm.Native.Utils.make (localRuntime);
  var Task = Elm.Native.Task.make (localRuntime);
  var List = Elm.Native.List.make (localRuntime);

  var pleaseReportThis = ' Should not happen, please report this as a bug in ElmFire!';

  function asMaybe (value) {
    if (typeof value === 'undefined' || value === null) {
      return { ctor: 'Nothing' };
    } else {
      return { ctor: 'Just', _0: value };
    }
  }

  function fromMaybe (maybe) {
    return maybe.ctor === 'Nothing' ? null : maybe._0;
  }

  function priority2fb (elmPriority) {
    return elmPriority.ctor === 'NoPriority' ? null : elmPriority._0;
  }

  function priority2elm (fbPriority) {
    switch (Object.prototype.toString.call (fbPriority)) {
      case '[object Number]':
        return {ctor: 'NumberPriority', _0: fbPriority};
      case '[object String]':
        return {ctor: 'StringPriority', _0: fbPriority};
      default:
        return {ctor: 'NoPriority'};
    }
  }

  function error2elm (tag, description) {
    return {
      _: {},
      tag: { ctor: tag },
      description: description
    };
  }

  var fbErrorMap = {
    PERMISSION_DENIED: 'PermissionError',
    UNAVAILABLE: 'UnavailableError',
    TOO_BIG: 'TooBigError'
  };

  function fbTaskError (fbError) {
    var tag = fbErrorMap [fbError.code];
    if (! tag) {
      tag = 'OtherFirebaseError';
    }
    return error2elm (tag, fbError.toString ());
  }

  function fbTaskFail (fbError) {
    return Task.fail (fbTaskError (fbError));
  }

  function exTaskError (exception) {
    return error2elm ('OtherFirebaseError', exception.toString ());
  }

  function exTaskFail (exception) {
    return Task.fail (exTaskError (exception));
  }

  function onCompleteCallbackRef (callback, res) {
    return function (err) {
      if (err) {
        callback (fbTaskFail (err));
      } else {
        callback (Task.succeed (res));
      }
    };
  }

  function getRefStep (location) {
    var ref;
    switch (location.ctor) {
      case 'UrlLocation':
        ref = new Firebase (location._0);
        break;
      case 'SubLocation':
        ref = getRefStep (location._1) .child (location._0);
        break;
      case 'ParentLocation':
        ref = getRefStep (location._0) .parent ();
        if (! ref) { throw ('Error: Root has no parent'); }
        break;
      case 'RootLocation':
        ref = getRefStep (location._0) .root ();
        break;
      case 'PushLocation':
        ref = getRefStep (location._0) .push ();
        break;
      case 'RefLocation':
        ref = location._0;
        break;
    }
    if (! ref) {
     throw ('Bad Firebase reference.' + pleaseReportThis);
    }
    return ref;
  }

  function getRef (location, failureCallback) {
    var ref;
    try {
      ref = getRefStep (location);
    }
    catch (exception) {
      failureCallback (Task.fail (error2elm ('LocationError', exception.toString ())));
    }
    return ref;
  }

  function toUrl (reference) {
    return reference .toString ();
  }

  function key (reference) {
    var res = reference .key ();
    if (res === null) {
      res = '';
    }
    return res;
  }

  function open (location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        callback (Task.succeed (ref));
      }
    });
  }

  function set (onDisconnect, value, location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var onComplete;
        if (onDisconnect) {
          ref = ref.onDisconnect ();
          onComplete = onCompleteCallbackRef (callback, Utils.Tuple0);
        } else {
          onComplete = onCompleteCallbackRef (callback, ref)
        }
        try { ref.set (value, onComplete); }
        catch (exception) { callback (exTaskFail (exception)); }
      }
    });
  }

  function setWithPriority (onDisconnect, value, priority, location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var onComplete;
        if (onDisconnect) {
          ref = ref.onDisconnect ();
          onComplete = onCompleteCallbackRef (callback, Utils.Tuple0);
        } else {
          onComplete = onCompleteCallbackRef (callback, ref)
        }
        try { ref.setWithPriority (value, priority2fb (priority), onComplete); }
        catch (exception) { callback (exTaskFail (exception)); }
      }
    });
  }

  function setPriority (priority, location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        try {
          ref.setPriority
                (priority2fb (priority), onCompleteCallbackRef (callback, ref));
        }
        catch (exception) { callback (exTaskFail (exception)); }
      }
    });
  }

  function update (onDisconnect, value, location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var onComplete;
        if (onDisconnect) {
          ref = ref.onDisconnect ();
          onComplete = onCompleteCallbackRef (callback, Utils.Tuple0);
        } else {
          onComplete = onCompleteCallbackRef (callback, ref)
        }
        try { ref.update (value, onComplete); }
        catch (exception) { callback (exTaskFail (exception)); }
      }
    });
  }

  function remove (onDisconnect, location) {
   return Task .asyncFunction (function (callback) {
     var ref = getRef (location, callback);
     if (ref) {
      var onComplete;
      if (onDisconnect) {
        ref = ref.onDisconnect ();
        onComplete = onCompleteCallbackRef (callback, Utils.Tuple0);
      } else {
        onComplete = onCompleteCallbackRef (callback, ref)
      }
       try { ref.remove (onComplete); }
       catch (exception) { callback (exTaskFail (exception)); }
     }
   });
 }

  function onDisconnectCancel (location) {
   return Task .asyncFunction (function (callback) {
     var ref = getRef (location, callback);
     if (ref) {
       try { ref.onDisconnect().cancel (onCompleteCallbackRef (callback, Utils.Tuple0)); }
       catch (exception) { callback (exTaskFail (exception)); }
     }
   });
 }

  function transaction (updateFunc, location, applyLocally) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var fbUpdateFunc = function (prevVal) {
          var action = updateFunc (asMaybe (prevVal));
          switch (action.ctor) {
            case 'Abort':  return;
            case 'Remove': return null;
            case 'Set':    return action._0;
            default: 	throw ('Bad action.' + pleaseReportThis);
          }
        };
        var onComplete = function (err, committed, fbSnapshot) {
          if (err) {
            callback (fbTaskFail (err));
          } else {
            var snapshot = snapshot2elm ('_transaction_', fbSnapshot, null);
            var res = Utils.Tuple2 (committed, snapshot);
            callback (Task.succeed (res));
          }
        };
        try { ref.transaction (fbUpdateFunc, onComplete, applyLocally); }
        catch (exception) {
          callback (exTaskFail (exception));
        }
      }
    });
  }

  // Store for current query subscriptions
  var sNum = 0;
  var subscriptions = {};

  function nextSubscriptionId () {
    return 'q' + (++sNum);
  }

  function queryEventType (query) {
    var eventType = 'Bad query type.' + pleaseReportThis;
    switch (query.ctor) {
      case 'ValueChanged': eventType = 'value'; break;
      case 'ChildAdded':   eventType = 'child_added'; break;
      case 'ChildChanged': eventType = 'child_changed'; break;
      case 'ChildRemoved': eventType = 'child_removed'; break;
      case 'ChildMoved':   eventType = 'child_moved'; break;
    }
    return eventType;
  }

  function queryOrderPoint (isPrio, filterFn, endPoint, ref) {
    if (isPrio) {
      var prio = priority2fb (endPoint._0);
      var key  = fromMaybe (endPoint._1);
      if (key === null) {
        ref = filterFn.call (ref, prio);
      } else {
        ref = filterFn.call (ref, prio, key);
      }
    } else {
      ref = filterFn.call (ref, endPoint);
    }
    return ref;
  }

  function queryOrderAndFilter (query, ref) {
    if (query._0) {
      var orderOptions = query._0;
      var rangeOptions = null;
      switch (orderOptions.ctor) {
        case 'NoOrder':
          break;
        case 'OrderByChild':
          ref = ref.orderByChild (orderOptions._0);
          rangeOptions = orderOptions._1;
          break;
        case 'OrderByValue':
          ref = ref.orderByValue ();
          rangeOptions = orderOptions._0;
          break;
        case 'OrderByKey':
          ref = ref.orderByKey ();
          rangeOptions = orderOptions._0;
          break;
        case 'OrderByPriority':
          ref = ref.orderByPriority ();
          rangeOptions = orderOptions._0;
          break;
        default: throw ('Bad query order option.' + pleaseReportThis);
      }
      if (rangeOptions) {
        var isPrio = orderOptions.ctor === 'OrderByPriority';
        switch (rangeOptions.ctor) {
          case 'NoRange':
            break;
          case 'StartAt':
            ref = queryOrderPoint (isPrio, ref.startAt, rangeOptions._0, ref);
            break;
          case 'EndAt':
            ref = queryOrderPoint (isPrio, ref.endAt,   rangeOptions._0, ref);
            break;
          case 'Range':
            ref = queryOrderPoint (isPrio, ref.startAt, rangeOptions._0, ref);
            ref = queryOrderPoint (isPrio, ref.endAt,   rangeOptions._1, ref);
            break;
          case 'EqualTo':
            ref = queryOrderPoint (isPrio, ref.equalTo, rangeOptions._0, ref);
            break;
          default: throw ('Bad query range option.' + pleaseReportThis);
        }
      }
    }
    if (query._1) {
      var limitOptions = query._1;
      switch (limitOptions.ctor) {
        case 'NoLimit': break;
        case 'LimitToFirst': ref = ref.limitToFirst (limitOptions._0); break;
        case 'LimitToLast':  ref = ref.limitToLast  (limitOptions._0); break;
        default: throw ('Bad query limit option.' + pleaseReportThis);
      }
    }
    return ref;
  }

  function snapshot2elm (subscription, fbSnapshot, prevKey) {
    var key = fbSnapshot .key ();
    if (key === null) {
      key = '';
    }
    var value = fbSnapshot .val ();
    return {
      _: {},
      subscription: subscription,
      key: key,
      reference: fbSnapshot .ref (),
      existing: value !== null,
      value: value,
      prevKey: asMaybe (prevKey),
      priority: priority2elm (fbSnapshot .getPriority ()),
      intern_: fbSnapshot
    };
  }

  function subscribeConditional (createResponseTask, createCancellationTask, query, location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var subscriptionId = nextSubscriptionId ();
        var onResponse = function (fbSnapshot, prevKey) {
          var snapshot = snapshot2elm (subscriptionId, fbSnapshot, prevKey);
          var responseTask = fromMaybe (createResponseTask (snapshot));
          if (responseTask !== null) {
            Task .perform (responseTask);
          }
        };
        var onCancel = function (err) {
          var cancellation = {
            ctor: 'QueryError',
            _0: subscriptionId,
            _1: fbTaskError (err)
          };
          Task .perform (createCancellationTask (cancellation));
        };
        var eventType = queryEventType (query);
        subscriptions [subscriptionId] = {
          ref: ref,
          eventType: eventType,
          callback: onResponse,
          createCancellationTask: createCancellationTask
        };
        try { queryOrderAndFilter (query, ref)
              .on (eventType, onResponse, onCancel); }
        catch (exception) {
          callback (exTaskFail (exception));
          return;
        }
        callback (Task.succeed (subscriptionId));
      }
    });
  }

  function unsubscribe (subscription) {
    return Task .asyncFunction (function (callback) {
      if (subscriptions.hasOwnProperty (subscription)) {
        var query = subscriptions [subscription];
        delete subscriptions [subscription];
        try { query.ref.off (query.eventType, query.callback); }
        catch (exception) {
          callback (exTaskFail (exception));
          return;
        }
        Task.perform (query.createCancellationTask ({
          ctor: 'Unsubscribed', _0: subscription
        }));
        callback (Task.succeed (Utils.Tuple0));
      } else {
        callback (Task.fail ({ ctor: 'UnknownSubscription' }));
      }
    });
  }

  function once (query, location) {
    return Task .asyncFunction (function (callback) {
      var ref = getRef (location, callback);
      if (ref) {
        var onResponse = function (fbSnapshot, prevKey) {
          var snapshot = snapshot2elm ('_once_', fbSnapshot, prevKey);
          callback (Task.succeed (snapshot));
        };
        var onCancel = function (err) {
          var error = fbTaskFail (err);
          callback (error);
        };
        var eventType = queryEventType (query);
        try { queryOrderAndFilter (query, ref)
              .once (eventType, onResponse, onCancel); }
        catch (exception) {
          callback (exTaskFail (exception));
        }
      }
    });
  }

  function toSnapshotList (snapshot) {
    var arr = [], prevKey = '';
    snapshot .intern_ .forEach (function (fbChildSnapshot) {
      var childSnapshot = snapshot2elm ('_child_', fbChildSnapshot, null);
      childSnapshot .prevKey = prevKey;
      prevKey = childSnapshot .key;
      arr .push (childSnapshot);
    });
    return List.fromArray (arr);
  }

  function toListGeneric (snapshot, mapSnapshot) {
   var arr = [];
   snapshot .intern_ .forEach (function (fbChildSnapshot) {
     arr .push (mapSnapshot (fbChildSnapshot));
   });
   return List.fromArray (arr);
 }

  function toValueList (snapshot) {
    return toListGeneric (snapshot, function (fbChildSnapshot) {
      return fbChildSnapshot .val ();
    });
  }

  function toKeyList (snapshot) {
    return toListGeneric (snapshot, function (fbChildSnapshot) {
      return fbChildSnapshot .key ();
    });
  }

  function toPairList (snapshot) {
    return toListGeneric (snapshot, function (fbChildSnapshot) {
      return Utils.Tuple2 (fbChildSnapshot .key (), fbChildSnapshot .val ());
    });
  }

  function exportValue (snapshot) {
    return snapshot .intern_ .exportVal ();
  }

  function setOffline (off) {
    return Task .asyncFunction (function (callback) {
      if (off) {
        Firebase.goOffline ();
      } else {
        Firebase.goOnline ();
      }
      callback (Task.succeed (Utils.Tuple0));
    });
  }

  var serverTimeStamp = Firebase.ServerValue.TIMESTAMP;

  return localRuntime.Native.ElmFire.values =
  {
    // Values exported to Elm
      toUrl: toUrl
    , key: key
    , open: open
    ,	set: F3 (set)
    ,	setWithPriority: F4 (setWithPriority)
    ,	setPriority: F2 (setPriority)
    ,	update: F3 (update)
    ,	remove: F2 (remove)
    , onDisconnectCancel: onDisconnectCancel
    ,	transaction: F3 (transaction)
    ,	subscribeConditional: F4 (subscribeConditional)
    ,	unsubscribe: unsubscribe
    ,	once: F2 (once)
    , toSnapshotList: toSnapshotList
    ,	toValueList: toValueList
    ,	toKeyList: toKeyList
    ,	toPairList: toPairList
    , exportValue: exportValue
    , setOffline: setOffline
    , serverTimeStamp: serverTimeStamp

    // Utilities for sub-modules
    , asMaybe: asMaybe
    , getRef: getRef
    , pleaseReportThis: pleaseReportThis
  };
};
