Elm.Native.ElmFire = {};
Elm.Native.ElmFire.make = function(localRuntime) {

	localRuntime.Native = localRuntime.Native || {};
	localRuntime.Native.ElmFire = localRuntime.Native.ElmFire || {};
	if (localRuntime.Native.ElmFire.values)
	{
		return localRuntime.Native.ElmFire.values;
	}

	var Utils = Elm.Native.Utils.make (localRuntime);
	var Task = Elm.Native.Task.make (localRuntime);
	var List = Elm.Native.List.make (localRuntime);

	var pleaseReportThis = ' Should not happen, please report this as a bug in ElmFire!'

	function asMaybe (value) {
		if (typeof value == 'undefined' || value === null) {
			return { ctor: 'Nothing' };
		} else {
			return { ctor: 'Just', _0: value };
		}
	}

	function fromMaybe (maybe) {
		return maybe.ctor === 'Nothing' ? null : maybe._0;
	}

	function encodePriority (elmPriority) {
		return elmPriority.ctor === 'NoPriority' ? null : elmPriority._0;
	}

	function decodePriority (fbPriority) {
		switch (toString.call (fbPriority)) {
			case "[object Number]":
				return {ctor: 'NumberPriority', _0: fbPriority};
				break;
			case "[object String]":
				return {ctor: 'StringPriority', _0: fbPriority};
				break;
			default:
				return {ctor: 'NoPriority'};
		}
	}

	function getRefUnsafe (location) {
		var ref;
		if (location.ctor === 'UrlLocation') {
			ref = new Firebase (location._0);
		} else if (location.ctor === 'SubLocation') {
			ref = getRefUnsafe (location._1) .child (location._0);
		} else if (location.ctor === 'ParentLocation') {
			ref = getRefUnsafe (location._0) .parent ();
			if (! ref) { throw ("Error: Root has no parent"); }
		} else if (location.ctor === 'RootLocation') {
			ref = getRefUnsafe (location._0) .root ();
		} else if (location.ctor === 'PushLocation') {
			ref = getRefUnsafe (location._0) .push ();
		} else if (location.ctor === 'RefLocation') {
			ref = location._0;
		}
		if (! ref) {
			throw ('Bad Firebase reference.' + pleaseReportThis);
		}
		return ref;
	}

	function getRef (location, callback) {
		var ref;
		try {
			ref = getRefUnsafe (location);
		}
		catch (exception) {
			callback (Task.fail ({ ctor: 'LocationError', _0: exception.toString () }));
			return null;
		}
		return ref;
	}

	function toUrl (reference) {
		return reference .toString ();
	}

	function key (reference) {
		var key = reference .key ();
		if (key === null) {
			key = '';
		}
		return key;
	}

	fbErrorMap = {
		PERMISSION_DENIED: 'PermissionError',
		UNAVAILABLE: 'UnavailableError',
		TOO_BIG: 'TooBigError'
	};

	function fbTaskError (fbError) {
		var ctor = fbErrorMap [fbError.code];
		if (! ctor) {
			ctor = 'FirebaseError';
		}
		return { ctor: ctor, _0: fbError.toString () };
	}

	function fbTaskFail (fbError) {
		return Task.fail (fbTaskError (fbError));
	}

	function onCompleteFn (callback, ref) {
		return function (err) {
			if (err) {
				callback (fbTaskFail (err));
			} else {
				callback (Task.succeed (ref));
			}
		};
	}

	function exTaskFail (exception) {
		return Task.fail ({ctor: 'FirebaseError', _0: exception.toString ()});
	}

	function open (location) {
		return Task .asyncFunction (function (callback) {
			var ref = getRef (location, callback);
			if (ref) {
				callback (Task.succeed (ref));
			}
		});
	}

	function set (value, location) {
		return Task .asyncFunction (function (callback) {
			var ref = getRef (location, callback);
			if (ref) {
				try { ref.set (value, onCompleteFn (callback, ref)); }
				catch (exception) { callback (exTaskFail (exception)); }
			}
		});
	}

	function setWithPriority (value, priority, location) {
		return Task .asyncFunction (function (callback) {
			var ref = getRef (location, callback);
			if (ref) {
				try { ref.setWithPriority
				        (value, encodePriority (priority), onCompleteFn (callback, ref)); }
				catch (exception) { callback (exTaskFail (exception)); }
			}
		});
	}

	function setPriority (priority, location) {
		return Task .asyncFunction (function (callback) {
			var ref = getRef (location, callback);
			if (ref) {
				try { ref.setPriority
				        (encodePriority (priority), onCompleteFn (callback, ref)); }
				catch (exception) { callback (exTaskFail (exception)); }
			}
		});
	}

	function update (value, location) {
		return Task .asyncFunction (function (callback) {
			var ref = getRef (location, callback);
			if (ref) {
				try { ref.update (value, onCompleteFn (callback, ref)); }
				catch (exception) { callback (exTaskFail (exception)); }
			}
		});
	}

	function remove (location) {
		return Task .asyncFunction (function (callback) {
			var ref = getRef (location, callback);
			if (ref) {
				try { ref.remove (onCompleteFn (callback, ref)); }
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
						case 'Set':    return action._0; break;
					}
				};
				var onComplete = function (err, committed, fbSnapshot) {
					if (err) {
						setTimeout (function () {
							callback (fbTaskFail (err));
						});
					} else {
						var snapshot = convertSnapshot ("_transaction_", fbSnapshot, null);
						var res = Utils.Tuple2 (committed, snapshot);
						setTimeout (function () {
							callback (Task.succeed (res));
						});
					}
				};
				try { ref.transaction (fbUpdateFunc, onComplete, applyLocally); }
				catch (exception) {
					callback (exTaskFail (exception));
				}
			}
		});
	}

	function transactionByTask (createUpdateTask, location, applyLocally) {
		return Task .asyncFunction (function (callback) {
			var ref = getRef (location, callback);
			if (ref) {
				var fbUpdateFunc = function (prevVal) {
					var updateTask = createUpdateTask (asMaybe (prevVal));
					var x = Task. perform (updateTask);
					// TODO: What is the right way to get a task's result?
					//       Do we have to employ andThen and onError for that?
					if (updateTask.tag == 'Succeed') {
						var action = updateTask.value;
						switch (action.ctor) {
							case 'Abort':  return;
							case 'Remove': return null;
							case 'Set':    return action._0; break;
						}
						// return undefined to abort when updateTask failed
					}
				};
				var onComplete = function (err, committed, fbSnapshot) {
					if (err) {
						setTimeout (function () {
							callback (fbTaskFail (err));
						});
					} else {
						var snapshot = convertSnapshot ("_transaction_", fbSnapshot, null);
						var res = Utils.Tuple2 (committed, snapshot);
						setTimeout (function () {
							callback (Task.succeed (res));
						});
					}
				};
				try { ref.transaction (fbUpdateFunc, onComplete, applyLocally); }
				catch (exception) {
					callback (exTaskFail (exception));
				}
			}
		});
	}

	var qNum = 0;
	var queries = {};

	function nextQueryId () {
		return 'q' + ++qNum;
	}

	function queryEventType (query) {
		var eventType = 'Bad query type.' + pleaseReportThis;
		if (query.queryEvent) {
			switch (query.queryEvent.ctor) {
				case 'ValueChanged': eventType = 'value'; break;
				case 'ChildAdded':   eventType = 'child_added'; break;
				case 'ChildChanged': eventType = 'child_changed'; break;
				case 'ChildRemoved': eventType = 'child_removed'; break;
				case 'ChildMoved':   eventType = 'child_moved'; break;
			}
		}
		return eventType;
	}

	function queryOrderAndFilter (query, ref) {
		if (query.orderByChildOrValue) {
			if (query.orderByChildOrValue.ctor == "Just") {
				ref = ref.orderByChild (query.orderByChildOrValue._0)
			} else {
				ref = ref.orderByValue ()
			}
		}
		if (query.orderByKey) {
			ref = ref.orderByKey ()
		}
		if (query.orderByPriority) {
			ref = ref.orderByPriority ()
		}

		if (query.startAtValue) {
			ref = ref.startAt  (query.startAtValue);
		}
		if (query.endAtValue) {
			ref = ref.endAt  (query.endAtValue);
		}
		if (query.startAtKey) {
			ref = ref.startAt  (query.startAtKey);
		}
		if (query.endAtKey) {
			ref = ref.endAt  (query.endAtKey);
		}
		var prio, key;
		if (query.startAtPriority) {
			prio = encodePriority (query.startAtPriority._0);
			key  = fromMaybe (query.startAtPriority._1);
			if (key === null) {
				ref = ref.startAt (prio)
			} else {
				ref = ref.startAt (prio, key)
			}
		}
		if (query.endAtPriority) {
			prio = encodePriority (query.endAtPriority._0);
			key  = fromMaybe (query.endAtPriority._1);
			if (key === null) {
				ref = ref.endAt (prio)
			} else {
				ref = ref.endAt (prio, key)
			}
		}

		if (query.limitToFirst) {
			ref = ref.limitToFirst (query.limitToFirst);
		}
		if (query.limitToLast) {
			ref = ref.limitToLast (query.limitToLast);
		}

		return ref;
	}

	function convertSnapshot (queryId, fbSnapshot, prevKey) {
		var key = fbSnapshot .key ();
		if (key === null) {
			key = '';
		}
		return {
			_: {},
			queryId: queryId,
			key: key,
			reference: fbSnapshot .ref (),
			value: asMaybe (fbSnapshot .val ()),
			prevKey: asMaybe (prevKey),
			priority: decodePriority (fbSnapshot .getPriority ()),
			intern_: fbSnapshot
		};
	}

	function subscribe (createResponseTask, createCancellationTask, query, location) {
		return Task .asyncFunction (function (callback) {
			var ref = getRef (location, callback);
			if (ref) {
				var queryId = nextQueryId ();
				var onResponse = function (fbSnapshot, prevKey) {
					var snapshot = convertSnapshot (queryId, fbSnapshot, prevKey);
					setTimeout (function () {
						Task .perform (createResponseTask (snapshot));
					});
				};
				var onCancel = function (err) {
					var cancellation = {
						ctor: 'QueryError',
						_0: queryId,
						_1: fbTaskError (err)
					};
					setTimeout (function () {
						Task .perform (createCancellationTask (cancellation));
					});
				};
				var eventType = queryEventType (query);
				queries [queryId] = {
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
				callback (Task.succeed (queryId));
			}
		});
	}

	function unsubscribe (queryId) {
		return Task .asyncFunction (function (callback) {
			if (queryId in queries) {
				var query = queries [queryId];
				delete queries [queryId];
				try { query.ref.off (query.eventType, query.callback); }
				catch (exception) {
					callback (exTaskFail (exception));
					return;
				}
				setTimeout (function () {
					Task.perform (query.createCancellationTask ({
						ctor: 'Unsubscribed', _0: queryId
					}));
				});
				callback (Task.succeed (Utils.Tuple0));
			} else {
				callback (Task.fail ({ ctor: 'UnknownQueryId' }));
			}
		});
	}

	function once (query, location) {
		return Task .asyncFunction (function (callback) {
			var ref = getRef (location, callback);
			if (ref) {
				var onResponse = function (fbSnapshot, prevKey) {
					var snapshot = convertSnapshot ("_once_", fbSnapshot, prevKey);
					setTimeout (function () {
						callback (Task.succeed (snapshot));
					});
				};
				var onCancel = function (err) {
					var error = fbTaskFail (err);
					setTimeout (function () {
						callback (error);
					});
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
		return toListGeneric (snapshot, function (fbChildSnapshot) {
			return convertSnapshot ("_child_", fbChildSnapshot, null);
		});
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

	function toListGeneric (snapshot, mapSnapshot) {
		var arr = [];
		snapshot .intern_ .forEach (function (fbChildSnapshot) {
			arr .push (mapSnapshot (fbChildSnapshot));
		});
		return List.fromArray (arr);
	}

	return localRuntime.Native.ElmFire.values =
	{	toUrl: toUrl
  , key: key
	, open: open
	,	set: F2 (set)
	,	setWithPriority: F3 (setWithPriority)
	,	setPriority: F2 (setPriority)
	,	update: F2 (update)
	,	remove: remove
	,	transaction: F3 (transaction)
	,	transactionByTask: F3 (transactionByTask)
	,	subscribe: F4 (subscribe)
	,	unsubscribe: unsubscribe
	,	once: F2 (once)
	, toSnapshotList: toSnapshotList
	,	toValueList: toValueList
	,	toKeyList: toKeyList
	,	toPairList: toPairList
	};
};
