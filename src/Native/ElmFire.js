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

	function getRefUnsafe (location) {
		var ref;
		if (location.ctor === 'UrlLocation') {
			ref = new Firebase (location._0);
		} else if (location.ctor === 'SubLocation') {
			ref = getRefUnsafe (location._1) .child (location._0);
		} else if (location.ctor === 'ParentLocation') {
			ref = getRefUnsafe (location._0) .parent ();
			if (! ref) { throw ("no parent"); }
		} else if (location.ctor === 'RootLocation') {
			ref = getRefUnsafe (location._0) .root ();
		} else if (location.ctor === 'RefLocation') {
			ref = location._0;
		}
		if (! ref) {
			throw ("Bad Firebase reference (should not happen)");
		}
		return ref;
	}

	function getRef (location) {
		var ref;
		try {
			ref = getRefUnsafe (location);
		}
		catch (exception) {
			return {error: "FireElm: " + exception.toString ()};
		}
		return {ref: ref};
	}

	function toUrl (reference) {
		return reference .toString ();
	}

	function open (location) {
		return Task .asyncFunction (function (callback) {
			locRef = getRef (location);
			if ('ref' in locRef) {
				callback (Task.succeed (locRef.ref ));
			} else {
				callback (Task.fail ({ ctor: 'FirebaseError', _0: locRef.error }));
			}
		});
	}

	function set (value, location) {
		return Task .asyncFunction (function (callback) {
			locRef = getRef (location);
			if ('ref' in locRef) {
				locRef.ref.set (value, function (err) {
					if (err) {
						callback (Task.fail ({ ctor: 'FirebaseError', _0: err.toString () }));
					} else {
						callback (Task.succeed (Utils.Tuple0));
					}
				});
			}
			else {
				callback (Task.fail ({ ctor: 'FirebaseError', _0: locRef.error }));
			}
		});
	}

	function remove (location) {
		return Task .asyncFunction (function (callback) {
			locRef = getRef (location);
			if ('ref' in locRef) {
				locRef.ref.remove (function (err) {
					if (err) {
						callback (Task.fail ({ ctor: 'FirebaseError', _0: err.toString () }));
					} else {
						callback (Task.succeed (Utils.Tuple0));
					}
				});
			}
			else {
				callback (Task.fail ({ ctor: 'FirebaseError', _0: locRef.error }));
			}
		});
	}

	var qNum = 0;
	var queries = {};

	function nextQueryId () {
		return 'q' + ++qNum;
	}

	function subscribe (responseAddress, query, location) {
		return Task .asyncFunction (function (callback) {
			locRef = getRef (location);
			if ('ref' in locRef) {
				var queryId = nextQueryId ();
				var onResponse = function (snapshot) {
					var val = snapshot .val (), maybeVal;
					if (val === null) {
						maybeVal = { ctor: 'Nothing' };
					} else {
						maybeVal = { ctor: 'Just', _0: val };
					}
					var res = {
						ctor: 'Data',
						_0: {
							_: {},
							queryId: queryId,
							refLocation: snapshot.ref().toString(),
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
					ref: locRef.ref,
					eventType: eventType,
					callback: onResponse
				};
				locRef.ref.on (eventType, onResponse, onCancel);
				callback (Task.succeed (queryId));
			}
			else {
				callback (Task.fail ({ ctor: 'FirebaseError', _0: locRef.error }));
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
		toUrl: toUrl,
		open: open,
		set: F2(set),
		remove: remove,
		subscribe: F3(subscribe),
		unsubscribe: unsubscribe
	};
};
