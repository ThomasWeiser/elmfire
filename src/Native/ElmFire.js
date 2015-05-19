Elm.Native.ElmFire = {};
Elm.Native.ElmFire.make = function(localRuntime) {

	localRuntime.Native = localRuntime.Native || {};
	localRuntime.Native.ElmFire = localRuntime.Native.ElmFire || {};
	if (localRuntime.Native.ElmFire.values)
	{
		return localRuntime.Native.ElmFire.values;
	}

	// var Dict = Elm.Dict.make(localRuntime);
	// var List = Elm.List.make(localRuntime);
	// var Maybe = Elm.Maybe.make(localRuntime);
	var Signal = Elm.Native.Signal.make (localRuntime);
	var Task = Elm.Native.Task.make (localRuntime);
	var Utils = Elm.Native.Utils.make (localRuntime);

	function getRefUnsafe (elmRef) {
		var rawRef;
		if (elmRef.ctor === 'LocationRef') {
			rawRef = new Firebase (elmRef._0);
		} else if (elmRef.ctor === 'SubRef') {
			rawRef = getRefUnsafe (elmRef._1) .child (elmRef._0);
		} else if (elmRef.ctor === 'ParentRef') {
			rawRef = getRefUnsafe (elmRef._0) .parent ();
			if (! rawRef) { throw ("no parent"); }
		} else if (elmRef.ctor === 'RawRef') {
			rawRef = elmRef._0;
		}
		if (! rawRef) {
			throw ("bad ref (should not happen)");
		}
		return rawRef;
	}

	function getRef (elmRef) {
		var rawRef;
		try {
			rawRef = getRefUnsafe (elmRef);
		}
		catch (exception) {
			return {error: "FireElm: " + exception.toString ()};
		}
		return {ref: rawRef};
	}

	function open (elmRef) {
		return Task .asyncFunction (function (callback) {
			deref = getRef (elmRef);
			if ('ref' in deref) {
				callback (Task.succeed ({ ctor: 'RawRef', _0: deref.ref }));
			} else {
				callback (Task.fail ({ ctor: 'FirebaseError', _0: deref.error }));
			}
		});
	}

	function set (value, elmRef) {
		return Task .asyncFunction (function (callback) {
			deref = getRef (elmRef);
			if ('ref' in deref) {
				deref.ref.set (value, function (err) {
					if (err) {
						callback (Task.fail ({ ctor: 'FirebaseError', _0: err.toString () }));
					} else {
						callback (Task.succeed (Utils.Tuple0));
					}
				});
			}
			else {
				callback (Task.fail ({ ctor: 'FirebaseError', _0: deref.error }));
			}
		});
	}

	function remove (elmRef) {
		return Task .asyncFunction (function (callback) {
			deref = getRef (elmRef);
			if ('ref' in deref) {
				deref.ref.remove (function (err) {
					if (err) {
						callback (Task.fail ({ ctor: 'FirebaseError', _0: err.toString () }));
					} else {
						callback (Task.succeed (Utils.Tuple0));
					}
				});
			}
			else {
				callback (Task.fail ({ ctor: 'FirebaseError', _0: deref.error }));
			}
		});
	}

	var qNum = 0;
	var queries = {};

	function nextQueryId () {
		return 'q' + ++qNum;
	}

	function subscribe (responseAddress, query, elmRef) {
		return Task .asyncFunction (function (callback) {
			deref = getRef (elmRef);
			if ('ref' in deref) {
				var queryId = nextQueryId ();
				var onResponse = function (snapshot) {
					var val = snapshot .val (), maybeVal;
					if (val === null) {
						maybeVal = { ctor: 'Nothing' };
					} else {
						maybeVal = { ctor: 'Just', _0: val };
					}
					var key = snapshot .key (), maybeKey;
					if (key === null) {
						maybeKey = { ctor: 'Nothing' };
					} else {
						maybeKey = { ctor: 'Just', _0: key };
					}
					var res = {
						ctor: 'Data',
						_0: {
							_: {},
							queryId: queryId,
							key: maybeKey,
							value: maybeVal
						}
					};
					setTimeout (function () {
						Task.perform (responseAddress._0 (res));
					}, 0);
				};
				var onCancel = function (err) {
					var res = {
						ctor: 'QueryCanceled',
						_0: queryId,
						_1: err .toString ()
					};
					setTimeout (function () {
						Task.perform (responseAddress._0 (res));
					}, 0);
				};
				eventType = 'badQuery';
				if (query.ctor === 'ValueChanged') {
					eventType = 'value';
				} else if (query.ctor === 'Child') {
					switch (query._0.ctor) {
						case 'Added':   eventType = 'child_added'; break;
						case 'Changed': eventType = 'child_changed'; break;
						case 'Removed': eventType = 'child_removed'; break;
						case 'Moved':   eventType = 'child_moved'; break;
					}
				}
				queries [queryId] = {
					ref: deref.ref,
					eventType: eventType,
					callback: onResponse
				};
				deref.ref.on (eventType, onResponse, onCancel);
				callback (Task.succeed (queryId));
			}
			else {
				callback (Task.fail ({ ctor: 'FirebaseError', _0: deref.error }));
			}
		});
	}

	function unsubscribe (queryId) {
		return Task .asyncFunction (function (callback) {
			if (queryId in queries) {
				var query = queries [queryId];
				query.ref.off (query.eventType, query.callback);
				callback (Task.succeed (Utils.Tuple0));
			} else {
				callback (Task.fail ({ ctor: 'FirebaseError', _0: 'unknown queryId' }));
			}
		});
	}
	return localRuntime.Native.ElmFire.values = {
		open: open,
		set: F2(set),
		remove: remove,
		subscribe: F3(subscribe),
		unsubscribe: unsubscribe
	};
};
