package reactivefl.core
{
	import spark.core.IDisplayText;
	
	import reactivefl.RFL;
	import reactivefl.concurrency.Scheduler;
	import reactivefl.disposables.CompositeDisposable;
	import reactivefl.disposables.Disposable;
	import reactivefl.disposables.RefCountDisposable;
	import reactivefl.disposables.SerialDisposable;
	import reactivefl.disposables.SingleAssignmentDisposable;
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObservable;
	import reactivefl.i.IObserver;
	import reactivefl.internals.Enumerable;
	import reactivefl.subjects.Subject;
	import reactivefl.vo.ValueWithInterval;
	import reactivefl.vo.ValueWithTimestamp;
	
	public class Observable implements IObservable
	{
		private var _subscribe:Function;
		public var forEach:Function = subscribe;
		public function Observable(subscribe:Function)
		{
			this._subscribe = subscribe;
		}
		
		public function subscribe(observerOrOnNext:Object, onError:Function = null, onCompleted:Function = null):IDisposable
		{
			var subscriber:IObserver;
			if(observerOrOnNext is Function){
				subscriber = Observer.create(observerOrOnNext as Function, onError, onCompleted);
			}else{
				subscriber = observerOrOnNext as IObserver;
			}
			return _subscribe(subscriber);
		}
		public function finalValue():AnonymousObservable{
			var source:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var hasValue:Boolean = false;
				var value:*;
				return source.subscribe(function (x:*):void {
					hasValue = true;
					value = x;
				}, observer.onError, function ():void {
					if (!hasValue) {
						observer.onError(new Error(RFL.sequenceContainsNoElements));
					} else {
						observer.onNext(value);
						observer.onCompleted();
					}
				});
			});
		}
		public function toArray():Observable{
			function accumulator(list:Array, i:int):Array {
				list.push(i);
				return list.slice(0);
			}
			return scan([], accumulator).startWith([]).finalValue();
		}
		
		//standard sequence operator
		public function defaultIfEmpty(defaultValue:* = null):Observable {
			var source:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var found:Boolean = false;
				return source.subscribe(function (x:*):void {
					found = true;
					observer.onNext(x);
				}, observer.onError, function ():void {
					if (!found) {
						observer.onNext(defaultValue);
					}
					observer.onCompleted();
				});
			});
		}
		public function select(selector:Function):Observable{
			var parent:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
//				var count:int = 0;
				return parent.subscribe(function (value:*):void {
					var result:*;
					try {
//						result = selector(value, count++);
						result = selector(value);
					} catch (exception:Error) {
						observer.onError(exception);
						return;
					}
					observer.onNext(result);
				}, observer.onError, observer.onCompleted);
			});
		}
		public function distinct(keySelector:Function = null, keySerializer:Function = null):Observable {
			keySelector ||= RFL.identity;
			keySerializer ||= RFL.defaultKeySerializer;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var hashSet:Object = {};
				return subscribe(function (x:*):void {
					var key:*, serializedKey:String, otherKey:String, hasMatch:Boolean = false;
					try {
						key = keySelector(x);
						serializedKey = keySerializer(key);
					} catch (exception:Error) {
						observer.onError(exception);
						return;
					}
					for (otherKey in hashSet) {
						if (serializedKey === otherKey) {
							hasMatch = true;
							break;
						}
					}
					if (!hasMatch) {
						hashSet[serializedKey] = null;
						observer.onNext(x);
					}
				}, observer.onError, observer.onCompleted);
			});
		}
		public function groupBy(keySelector:Function, elementSelector:Function = null, keySerializer:Function = null):Observable {
			return groupByUntil(keySelector, function ():Observable {
				return ObservableUtil.never();
			}, elementSelector, keySerializer);
		}
		public function groupByUntil(keySelector:Function, durationSelector:Function, elementSelector:Function = null, keySerializer:Function= null):Observable {
			var source:Observable = this;
			elementSelector ||= RFL.identity;
			keySerializer ||= RFL.defaultKeySerializer;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var map:Object = {},
				groupDisposable:CompositeDisposable = new CompositeDisposable(),
				refCountDisposable:RefCountDisposable = new RefCountDisposable(groupDisposable);
				groupDisposable.add(source.subscribe(function (x:*):void {
					var duration:Observable, 
					durationGroup:GroupedObservable, 
					element:*, expire:Function, fireNewMapEntry:Boolean, 
					group:GroupedObservable, key:*, serializedKey:String, md:SingleAssignmentDisposable, writer:Subject, w:String;
					try {
						key = keySelector(x);
						serializedKey = keySerializer(key);
					} catch (e:Error) {
						for (w in map) {
							map[w].onError(e);
						}
						observer.onError(e);
						return;
					}
					fireNewMapEntry = false;
					try {
						writer = map[serializedKey];
						if (!writer) {
							writer = new Subject();
							map[serializedKey] = writer;
							fireNewMapEntry = true;
						}
					} catch (e:Error) {
						for (w in map) {
							map[w].onError(e);
						}
						observer.onError(e);
						return;
					}
					if (fireNewMapEntry) {
						group = new GroupedObservable(key, writer, refCountDisposable);
						durationGroup = new GroupedObservable(key, writer);
						try {
							duration = durationSelector(durationGroup);
						} catch (e:Error) {
							for (w in map) {
								map[w].onError(e);
							}
							observer.onError(e);
							return;
						}
						observer.onNext(group);
						md = new SingleAssignmentDisposable();
						groupDisposable.add(md);
						expire = function ():void {
							if (serializedKey in map) {
								delete map[serializedKey];
								writer.onCompleted();
							}
							groupDisposable.remove(md);
						};
						md.setDisposable(duration.take(1).subscribe(RFL.noop, function (exn:Error):void {
							for (w in map) {
								map[w].onError(exn);
							}
							observer.onError(exn);
						}, expire));
					}
					try {
						element = elementSelector(x);
					} catch (e:Error) {
						for (w in map) {
							map[w].onError(e);
						}
						observer.onError(e);
						return;
					}
					writer.onNext(element);
				}, function (ex:Error):void {
					for (var w:String in map) {
						map[w].onError(ex);
					}
					observer.onError(ex);
				}, function ():void {
					for (var w:String in map) {
						map[w].onCompleted();
					}
					observer.onCompleted();
				}));
				return refCountDisposable;
			});
		}
		public function selectMany(selector:Object, resultSelector:Function = null):Observable {
			if (resultSelector != null) {
				return selectMany(function (x:*) :Observable{
					return selector(x).select(function (y:*):* {
						return resultSelector(x, y);
					});
				});
			}
			if (selector is Function) {
				return select(selector as Function).mergeObservable();
			}
			return select(function ():Object {return selector;}).mergeObservable();
		}
		public function skip(count:int):Observable {
			if (count < 0) {
				throw new Error(RFL.argumentOutOfRange);
			}
			var observable:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var remaining:int = count;
				return observable.subscribe(function (x:*):void {
					if (remaining <= 0) {
						observer.onNext(x);
					} else {
						remaining--;
					}
				}, observer.onError, observer.onCompleted);
			});
		};
		public function skipWhile(predicate:Function):Observable {
			var source:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var i:int = 0, running:Boolean = false;
				return source.subscribe(function (x:*):void {
					if (!running) {
						try {
							running = !predicate(x, i++);
						} catch (e:Error) {
							observer.onError(e);
							return;
						}
					}
					if (running) {
						observer.onNext(x);
					}
				}, observer.onError, observer.onCompleted);
			});
		}
		public function take(count:int, scheduler:Scheduler = null):Observable {
			if (count < 0) {
				throw new Error(RFL.argumentOutOfRange);
			}
			if (count === 0) {
				return ObservableUtil.empty(scheduler);
			}
			var observable:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var remaining:int = count;
				return observable.subscribe(function (x:*):void {
					if (remaining > 0) {
						remaining--;
						observer.onNext(x);
						if (remaining === 0) {
							observer.onCompleted();
						}
					}
				}, observer.onError, observer.onCompleted);
			});
		}
		public function takeWhile(predicate:Function):Observable {
			var observable:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var i:int = 0, running:Boolean = true;
				return observable.subscribe(function (x:*):void {
					if (running) {
						try {
							running = predicate(x, i++);
						} catch (e:Error) {
							observer.onError(e);
							return;
						}
						if (running) {
							observer.onNext(x);
						} else {
							observer.onCompleted();
						}
					}
				}, observer.onError, observer.onCompleted);
			});
		}
		public function where(predicate:Function):Observable {
			var parent:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
//				var count:int = 0;
				return parent.subscribe(function (value:*):void {
					var shouldRun:Boolean;
					try {
//						shouldRun = predicate(value, count++);
						shouldRun = predicate(value);
					} catch (exception:Error) {
						observer.onError(exception);
						return;
					}
					if (shouldRun) {
						observer.onNext(value);
					}
				}, observer.onError, observer.onCompleted);
			});
		}
		
		//single
		public function asObservable():Observable{
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return subscribe(observer);
			});
		}
		public function scan(param0:Object, accumulator:Function = null):Observable
		{
			var seed:Array;
			if(accumulator == null)accumulator = param0 as Function;
			else seed = param0 as Array;
			var source:Observable = this;
			return ObservableUtil.defer(function ():Observable {
				var hasAccumulation:Boolean = false, accumulation:Array;
				return source.select(function (x:*,i:int):Array {
					if (hasAccumulation) {
						accumulation = accumulator(accumulation, x);
					} else {
						accumulation = seed!=null ? accumulator(seed, x) : x;
						hasAccumulation = true;
					}
					return accumulation;
				});
			});
		}
		public function repeat(repeatCount:int):Observable {
			return Enumerable.repeat(this, repeatCount).concat();
		}
		public function finallyAction(action:Function) :Observable{
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var subscription:IDisposable = subscribe(observer);
				return Disposable.create(function ():void {
					try {
						subscription.dispose();
					} catch (e:Error) { 
						throw e;                    
					} finally {
						action();
					}
				});
			});
		}
		public function ignoreElements():Observable {
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return subscribe(RFL.noop, observer.onError, observer.onCompleted);
			});
		}
		public function retry(retryCount:int=-1) :Observable{
			return Enumerable.repeat(this, retryCount).catchException();
		}
		public function skipLast(count:int):Observable {
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var q:Array = [];
				return subscribe(function (x:*):void {
					q.push(x);
					if (q.length > count) {
						observer.onNext(q.shift());
					}
				}, observer.onError, observer.onCompleted);
			});
		}
		public function takeLast(count:int, scheduler:Scheduler = null):Observable {
			return this.takeLastBuffer(count).selectMany(function (xs:Array):Observable { return ObservableUtil.fromArray(xs, scheduler); });
		}
		public function takeLastBuffer(count:int):Observable {
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var q:Array = [];
				return subscribe(function (x:*):void {
					q.push(x);
					if (q.length > count) {
						q.shift();
					}
				}, observer.onError, function ():void {
					observer.onNext(q);
					observer.onCompleted();
				});
			});
		}
		public function startWith(...args):Observable
		{
			var scheduler:Scheduler;
			if (args.length > 0 && args[0] is Scheduler) {
				scheduler = args.shift() as Scheduler;
			} else {
				scheduler = RFL.immediateScheduler;
			}
			return Enumerable.forEach([ObservableUtil.fromArray(args, scheduler), this]).concat();
		}
		public function distinctUntilChanged(keySelector:Function = null, comparer:Function = null):Observable{
			keySelector ||= RFL.identity;
			comparer ||= RFL.defaultComparer;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var hasCurrentKey:Boolean = false, currentKey:*;
				return subscribe(function (value:*):void {
					var comparerEquals:Boolean = false, key:*;
					try {
						key = keySelector(value);
					} catch (exception:Error) {
						observer.onError(exception);
						return;
					}
					if (hasCurrentKey) {
						try {
							comparerEquals = comparer(currentKey, key);
						} catch (exception:Error) {
							observer.onError(exception);
							return;
						}
					}
					if (!hasCurrentKey || !comparerEquals) {
						hasCurrentKey = true;
						currentKey = key;
						observer.onNext(value);
					}
				}, observer.onError, observer.onCompleted);
			});
		}
		public function doAction(observerOrOnNext:Object, onError:Function = null, onCompleted:Function = null):Observable {
			var source:Observable = this, onNextFunc:Function;
			if (observerOrOnNext is Function) {
				onNextFunc = observerOrOnNext as Function;
			} else {
				onNextFunc = observerOrOnNext.onNext;
				onError = observerOrOnNext.onError;
				onCompleted = observerOrOnNext.onCompleted;
			}
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return source.subscribe(function (x:*):void {
					try {
						onNextFunc(x);
					} catch (e:Error) {
						observer.onError(e);
					}
					observer.onNext(x);
				}, function (exception:Error) :void{
					if (onError == null) {
						observer.onError(exception);
					} else {
						try {
							onError(exception);
						} catch (e:Error) {
							observer.onError(e);
						}
						observer.onError(exception);
					}
				}, function () :void{
					if (onCompleted == null) {
						observer.onCompleted();
					} else {
						try {
							onCompleted();
						} catch (e:Error) {
							observer.onError(e);
						}
						observer.onCompleted();
					}
				});
			});
		};
		public function windowWithCount(count:int,skip:int = -1):Observable{
			if (count <= 0) {
				throw new Error(RFL.argumentOutOfRange);
			}
			if (skip == -1) {
				skip = count;
			}
			if (skip <= 0) {
				throw new Error(RFL.argumentOutOfRange);
			}
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var m:SingleAssignmentDisposable = new SingleAssignmentDisposable(),
				refCountDisposable:RefCountDisposable = new RefCountDisposable(m),
				n:int = 0,
				q:Vector.<Subject> = new <Subject>[],
				createWindow:Function = function ():void {
					var s:Subject = new Subject();
					q.push(s);
					observer.onNext(RFL.addRef(s, refCountDisposable));
				};
				createWindow();
				m.setDisposable(subscribe(function (x:*):void {
					var s:Subject;
					for (var i:int = 0, len:int = q.length; i < len; i++) {
						q[i].onNext(x);
					}
					var c:int = n - count + 1;
					if (c >= 0 && c % skip === 0) {
						s = q.shift();
						s.onCompleted();
					}
					n++;
					if (n % skip === 0) {
						createWindow();
					}
				}, function (exception:Error):void {
					while (q.length > 0) {
						q.shift().onError(exception);
					}
					observer.onError(exception);
				}, function ():void {
					while (q.length > 0) {
						q.shift().onCompleted();
					}
					observer.onCompleted();
				}));
				return refCountDisposable;
			});
		}
		public function bufferWithCount(count:int, skip:int = -1) :Observable{
			if (skip === -1) {
				skip = count;
			}
			return windowWithCount(count, skip).selectMany(function (x:Observable):Observable {
				return x.toArray();
			}).where(function (x:Array):Boolean {
				return x.length > 0;
			});
		}
		public function dematerialize():Observable {
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return subscribe(function (x:Notification):* {
					return x.accept(observer);
				}, observer.onError, observer.onCompleted);
			});
		}
		public function materialize():Observable {
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return subscribe(function (value:*):void {
					observer.onNext(Notification.createOnNext(value));
				}, function (exception:Error):void {
					observer.onNext(Notification.createOnError(exception));
					observer.onCompleted();
				}, function ():void {
					observer.onNext(Notification.createOnCompleted());
					observer.onCompleted();;
				});
			});
		}
		//multiple
		/**
		 * 取得最先到达的信号
		 * @param rightSource
		 * @return 
		 * 
		 */		
		public function amb(rightSource:IObservable):Observable {
			var leftSource:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				
				var choice:String,
				leftChoice:String = 'L', rightChoice:String = 'R',
				leftSubscription:SingleAssignmentDisposable = new SingleAssignmentDisposable(),
				rightSubscription:SingleAssignmentDisposable = new SingleAssignmentDisposable();
				
				function choiceL():void {
					if (!choice) {
						choice = leftChoice;
						rightSubscription.dispose();
					}
				}
				
				function choiceR():void{
					if (!choice) {
						choice = rightChoice;
						leftSubscription.dispose();
					}
				}
				
				leftSubscription.setDisposable(leftSource.subscribe(function (left:*):void {
					choiceL();
					if (choice == leftChoice) {
						observer.onNext(left);
					}
				}, function (err:Error) :void{
					choiceL();
					if (choice == leftChoice) {
						observer.onError(err);
					}
				}, function ():void{
					choiceL();
					if (choice == leftChoice) {
						observer.onCompleted();
					}
				}));
				
				rightSubscription.setDisposable(rightSource.subscribe(function (right:*):void {
					choiceR();
					if (choice == rightChoice) {
						observer.onNext(right);
					}
				}, function (err:Error):void {
					choiceR();
					if (choice == rightChoice) {
						observer.onError(err);
					}
				}, function () :void{
					choiceR();
					if (choice == rightChoice) {
						observer.onCompleted();
					}
				}));
				
				return new CompositeDisposable(leftSubscription, rightSubscription);
			});
		}
		public function concat(...args):Observable {
			var items:Array = args;
			items.unshift(this);
			return ObservableUtil.concat.apply(this,items);
		}
		public function mergeObservable():Observable{
			var sources:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var group:CompositeDisposable = new CompositeDisposable(),
				isStopped:Boolean = false,
				m:SingleAssignmentDisposable = new SingleAssignmentDisposable();
				group.add(m);
				m.setDisposable(sources.subscribe(function (innerSource:Observable):void {
					var innerSubscription:SingleAssignmentDisposable = new SingleAssignmentDisposable();
					group.add(innerSubscription);
					innerSubscription.setDisposable(innerSource.subscribe(function (x:*):void {
						observer.onNext(x);
					}, observer.onError, function ():void {
						group.remove(innerSubscription);
						if (isStopped && group.length == 1) {
							observer.onCompleted();
						}
					}));
				}, observer.onError, function ():void {
					isStopped = true;
					if (group.length === 1) {
						observer.onCompleted();
					}
				}));
				return group;
			});
		}
		public function merge(maxConcurrentOrOther:Object):Observable {
			if (typeof maxConcurrentOrOther != 'number') {
				return ObservableUtil.merge(this, maxConcurrentOrOther);
			}
			var sources:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var activeCount:int = 0,
				group:CompositeDisposable = new CompositeDisposable(),
				isStopped:Boolean = false,
				q:Array = [],
				subscribe:Function = function (xs:IObservable):void {
					var subscription:SingleAssignmentDisposable = new SingleAssignmentDisposable();
					group.add(subscription);
					subscription.setDisposable(xs.subscribe(observer.onNext, observer.onError, function () :void{
						var s:IObservable;
						group.remove(subscription);
						if (q.length > 0) {
							s = q.shift();
							subscribe(s);
						} else {
							activeCount--;
							if (isStopped && activeCount === 0) {
								observer.onCompleted();
							}
						}
					}));
				};
				group.add(sources.subscribe(function (innerSource:IObservable):void {
					if (activeCount < maxConcurrentOrOther) {
						activeCount++;
						subscribe(innerSource);
					} else {
						q.push(innerSource);
					}
				}, observer.onError, function ():void {
					isStopped = true;
					if (activeCount === 0) {
						observer.onCompleted();
					}
				}));
				return group;
			});
		}
		public function onErrorResumeNext(second:IObservable):Observable {
			if (!second) {
				throw new Error('Second observable is required');
			}
			return ObservableUtil.onErrorResumeNext([this, second]);
		}
		public function skipUntil(other:IObservable):Observable {
			var source:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable  {
				var isOpen:Boolean = false;
				var disposables:CompositeDisposable = new CompositeDisposable(source.subscribe(function (left:*):void {
					if (isOpen) {
						observer.onNext(left);
					}
				}, observer.onError, function ():void {
					if (isOpen) {
						observer.onCompleted();
					}
				}));
				var rightSubscription:SingleAssignmentDisposable = new SingleAssignmentDisposable();
				disposables.add(rightSubscription);
				rightSubscription.setDisposable(other.subscribe(function () :void{
					isOpen = true;
					rightSubscription.dispose();
				}, observer.onError, function ():void {
					rightSubscription.dispose();
				}));
				return disposables;
			});
		}
		public function takeUntil(other:IObservable):Observable {
			var source:Observable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable  {
				return new CompositeDisposable(
					source.subscribe(observer),
					other.subscribe(function(x:*):void{observer.onCompleted();}, observer.onError, RFL.noop)
				);
			});
		}
		public function zip (...args):Observable {
			function zipArray(second:Array, resultSelector:Function):Observable {
				var first:Observable = this;
				return new AnonymousObservable(function (observer:IObserver):IDisposable  {
					var index:int = 0, len:uint = second.length;
					return first.subscribe(function (left:*):void {
						if (index < len) {
							var right:* = second[index++], result:*;
							try {
								result = resultSelector(left, right);
							} catch (e:Error) {
								observer.onError(e);
								return;
							}
							observer.onNext(result);
						} else {
							observer.onCompleted();
						}
					}, observer.onError, observer.onCompleted);
				});
			}    
			
			if (args[0] is Array) {
				return zipArray.apply(this, args);
			}
			var parent:Observable = this, sources:Array = args, resultSelector:Function = sources.pop();
			sources.unshift(parent);
			return new AnonymousObservable(function (observer:IObserver):IDisposable  {
				var n:uint = sources.length,
				queues:Array = RFL.arrayInitialize(n, function ():Array { return []; }),
				isDone:Array = RFL.arrayInitialize(n, function ():Boolean { return false; });
				var next:Function = function (i:int):void {
					var res:*, queuedValues:Array;
					if (queues.every(function (x:Array,index:int,array:Array):Boolean { return x.length > 0; })) {
						try {
							queuedValues = queues.map(function (x:Array,index:int,array:Array):* { return x.shift(); });
							res = resultSelector.apply(parent, queuedValues);
						} catch (ex:Error) {
							observer.onError(ex);
							return;
						}
						observer.onNext(res);
					} else if (isDone.filter(function (x:Boolean, j:int,array:Array):Boolean { return j !== i; }).every(function (x:Boolean,index:int,array:Array):Boolean { return x; })) {
						observer.onCompleted();
					}
				};
				
				function done(i:int):void {
					isDone[i] = true;
					if (isDone.every(function (x:Boolean,index:int,array:Array):Boolean { return x; })) {
						observer.onCompleted();
					}
				}
				
				var subscriptions:Array = new Array(n);
				for (var idx:int = 0; idx < n; idx++) {
					subscriptions[idx] = new SingleAssignmentDisposable();
					subscriptions[idx].setDisposable(sources[idx].subscribe(function (x:*):void {
						queues[idx].push(x);
						next(idx);
					}, observer.onError, function ():void {
						done(idx);
					}));
				}
				return new CompositeDisposable(subscriptions);
			});
		}
		//experimental
		public function doWhile(condition:Function):Observable {
			return ObservableUtil.concat([this, ObservableUtil.whileDo(condition, this)]);
		}
		//time
		public function throttle(dueTime:Number, scheduler:Scheduler = null):Observable {
			scheduler ||= RFL.timeoutScheduler;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var cancelable:SerialDisposable = new SerialDisposable(), 
				hasvalue:Boolean = false, id:int = 0, subscription:IDisposable, value:* = null;
				subscription = subscribe(function (x:*):void {
					var currentId:int, d:SingleAssignmentDisposable;
					hasvalue = true;
					value = x;
					id++;
					currentId = id;
					d = new SingleAssignmentDisposable();
					cancelable.disposable(d);
					d.disposable(scheduler.scheduleWithRelative(dueTime, function () :void{
						if (hasvalue && id === currentId) {
							observer.onNext(value);
						}
						hasvalue = false;
					}));
				}, function (exception:Error):void {
					cancelable.dispose();
					observer.onError(exception);
					hasvalue = false;
					id++;
				}, function ():void {
					cancelable.dispose();
					if (hasvalue) {
						observer.onNext(value);
					}
					observer.onCompleted();
					hasvalue = false;
					id++;
				});
				return new CompositeDisposable(subscription, cancelable);
			});
		}
		public function timeInterval(scheduler:Scheduler):Observable {
			scheduler ||= RFL.timeoutScheduler;
			return ObservableUtil.defer(function () :Observable{
				var last:Number = scheduler.now();
				return select(function (x:*):Object {
					var now:Number = scheduler.now(), span:Number = now - last;
					last = now;
					return new ValueWithInterval(x,span);
				});
			});
		}
		public function timeout(dueTime:Object, other:Observable = null, scheduler:Scheduler = null) :Observable{
			var schedulerMethod:Function;
			other || (other = ObservableUtil.throwException(new Error('Timeout')));
			scheduler ||= RFL.timeoutScheduler;
			if (dueTime is Date) {
				dueTime = (dueTime as Date).getTime();
				schedulerMethod = scheduler.scheduleWithAbsolute;
			} else {
				schedulerMethod = scheduler.scheduleWithRelative;
			}
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var createTimer:Function,
				id:int = 0,
				original:SingleAssignmentDisposable = new SingleAssignmentDisposable(),
				subscription:SerialDisposable = new SerialDisposable(),
				switched:Boolean = false,
				timer:SerialDisposable = new SerialDisposable();
				subscription.disposable(original);
				createTimer = function ():void {
					var myId:int = id;
					timer.disposable(schedulerMethod(dueTime as Number, function ():void {
						switched = id === myId;
						//timerWins=switched
						if (switched) {
							subscription.disposable(other.subscribe(observer));
						}
					}));
				};
				createTimer();
				original.disposable(subscribe(function (x:*):void {
					//onNextWins = !switched
					if (!switched) {
						id++;
						observer.onNext(x);
						createTimer();
					}
				}, function (e:Error) :void{
//					var onErrorWins = !switched;
					if (!switched) {
						id++;
						observer.onError(e);
					}
				}, function ():void {
//					var onCompletedWins:Boolean = !switched;
					if (!switched) {
						id++;
						observer.onCompleted();
					}
				}));
				return new CompositeDisposable(subscription, timer);
			});
		}
		public function sample(intervalOrSampler:Object, scheduler:Scheduler = null) :Observable{
			scheduler ||= RFL.timeoutScheduler;
			var sampler:IObservable = intervalOrSampler is IObservable?intervalOrSampler as IObservable:ObservableUtil.interval(intervalOrSampler as Number, scheduler);
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var atEnd:Boolean, value:Boolean, hasValue:Boolean;
				function sampleSubscribe():void{
					if (hasValue) {
						hasValue = false;
						observer.onNext(value);
					}
					if (atEnd) {
						observer.onCompleted();
					}
				}
				return new CompositeDisposable(
					subscribe(function (newValue:*):void {
						hasValue = true;
						value = newValue;
					}, observer.onError, function ():void  {
						atEnd = true;
					}),
					sampler.subscribe(sampleSubscribe, observer.onError, sampleSubscribe)
				)
			});
		}
		private function observableDelayTimeSpan(dueTime:Number, scheduler:Scheduler):Observable {
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var active:Boolean = false,
				cancelable:SerialDisposable = new SerialDisposable(),
				exception:Error = null,
				q:Vector.<ValueWithTimestamp> = new <ValueWithTimestamp>[],
				running:Boolean = false,
				subscription:IDisplayText = materialize().timestamp(scheduler).subscribe(function (notification:ValueWithTimestamp):void {
					var d:SingleAssignmentDisposable, shouldRun:Boolean;
					if (notification.value.kind === 'E') {
						q  = new <ValueWithTimestamp>[notification];
						exception = notification.value.exception;
						shouldRun = !running;
					} else {
						q.push(new ValueWithTimestamp( notification.value,  notification.timestamp + dueTime ));
						shouldRun = !active;
						active = true;
					}
					if (shouldRun) {
						if (exception !== null) {
							observer.onError(exception);
						} else {
							d = new SingleAssignmentDisposable();
							cancelable.disposable(d);
							d.disposable(scheduler.scheduleRecursiveWithRelative(dueTime, function (self:Function):void {
								var e:Error, recurseDueTime:int, result:Notification, shouldRecurse:Boolean;
								if (exception !== null) {
									return;
								}
								running = true;
								do {
									result = null;
									if (q.length > 0 && q[0].timestamp - scheduler.now() <= 0) {
										result = q.shift().value;
									}
									if (result !== null) {
										result.accept(observer);
									}
								} while (result !== null);
								shouldRecurse = false;
								recurseDueTime = 0;
								if (q.length > 0) {
									shouldRecurse = true;
									recurseDueTime = Math.max(0, q[0].timestamp - scheduler.now());
								} else {
									active = false;
								}
								e = exception;
								running = false;
								if (e !== null) {
									observer.onError(e);
								} else if (shouldRecurse) {
									self(recurseDueTime);
								}
							}));
						}
					}
				});
				return new CompositeDisposable(subscription, cancelable);
			});
		}
		private function observableDelayDate(dueTime:Number, scheduler:Scheduler):Observable {
			return ObservableUtil.defer(function ():Observable {
				var timeSpan:Number = dueTime - scheduler.now();
				return observableDelayTimeSpan(timeSpan, scheduler);
			});
		}
		public function delay(dueTime:Object, scheduler:Scheduler = null):Observable {
			scheduler ||= RFL.timeoutScheduler;
			return dueTime is Date ?
				observableDelayDate((dueTime as Date).getTime(), scheduler) :
				observableDelayTimeSpan(dueTime as Number, scheduler);
		}
		public function timestamp(scheduler:Scheduler = null):Observable {
			scheduler ||= RFL.timeoutScheduler;
			return select(function (x:*) :ValueWithTimestamp{
				return new ValueWithTimestamp(x,scheduler.now());
			});
		}
	}
}