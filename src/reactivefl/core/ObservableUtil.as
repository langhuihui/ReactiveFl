package reactivefl.core
{
	import flash.events.IEventDispatcher;
	
	import reactivefl.RFL;
	import reactivefl.argsOrArray;
	import reactivefl.concurrency.Scheduler;
	import reactivefl.disposables.CompositeDisposable;
	import reactivefl.disposables.Disposable;
	import reactivefl.disposables.SerialDisposable;
	import reactivefl.disposables.SingleAssignmentDisposable;
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObservable;
	import reactivefl.i.IObserver;
	import reactivefl.internals.Enumerable;
	import reactivefl.internals.Enumerator;

	public class ObservableUtil
	{
		public function ObservableUtil()
		{
		}
		public static function throwException(exception:Error, scheduler:Scheduler = null):Observable {
			scheduler ||= RFL.immediateScheduler;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return scheduler.schedule(function ():void {
					observer.onError(exception);
				});
			});
		}
		public static function defer(observableFactory:Function):AnonymousObservable{
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var result:Observable;
				try {
					result = observableFactory();
				} catch (e:Error) {
					return throwException(e).subscribe(observer);
				}
				return result.subscribe(observer);
			});
		}
		public static function fromArray(array:Array, scheduler:Scheduler):Observable{
			scheduler ||= RFL.currentThreadScheduler;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var count:int = 0;
				return scheduler.scheduleRecursive(function (self:Function):void {
					if (count < array.length) {
						observer.onNext(array[count++]);
						self();
					} else {
						observer.onCompleted();
					}
				});
			});
		}
		public static function repeat(value:*, repeatCount:int = -1, scheduler:Scheduler = null):Observable {
			scheduler ||= RFL.currentThreadScheduler;
			return returnValue(value, scheduler).repeat(repeatCount);
		}
		public static function returnValue(value:*, scheduler:Scheduler):Observable {
			scheduler ||= RFL.immediateScheduler;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return scheduler.schedule(function ():void {
					observer.onNext(value);
					observer.onCompleted();
				});
			});
		}
		public static function merge (...args):Observable {
			var scheduler:Scheduler, sources:Array;
			if (!args[0]) {
				scheduler = RFL.immediateScheduler;
				sources = args.slice(1);
			} else if (args[0].now) {
				scheduler = args[0];
				sources = args.slice(1);
			} else {
				scheduler = RFL.immediateScheduler;
				sources = args;
			}
			if (sources[0] is Array) {
				sources = sources[0];
			}
			return fromArray(sources, scheduler).mergeObservable();
		} 
		public static function onErrorResumeNext(...args) :Observable{
			var sources:Array = argsOrArray(args);
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var pos:int = 0, subscription:SerialDisposable = new SerialDisposable(),
				cancelable:IDisposable = RFL.immediateScheduler.scheduleRecursive(function (self:Function):void {
					var current:IObservable, d:SingleAssignmentDisposable;
					if (pos < sources.length) {
						current = sources[pos++];
						d = new SingleAssignmentDisposable();
						subscription.setDisposable(d);
						d.setDisposable(current.subscribe(observer.onNext, self, self));
					} else {
						observer.onCompleted();
					}
				});
				return new CompositeDisposable(subscription, cancelable);
			});
		}
		public static function empty(scheduler:Scheduler = null) :Observable{
			scheduler ||= RFL.immediateScheduler;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return scheduler.schedule(observer.onCompleted);
			});
		}
		public static function never():Observable {
			return new AnonymousObservable(function (x:*):IDisposable {
				return Disposable.empty;
			});
		}
		public static function amb(...args):Observable {
			var acc:Observable = never(),
				items:Array = argsOrArray(args);
			for (var i:int = 0, len:uint = items.length; i < len; i++) {
				acc = acc.amb(items[i]);
			}
			return acc;
		}
		
		public static function concat(...args):Observable
		{
			return Enumerable.forEach(argsOrArray(args)).concat();
		}
		
		public static function ifThen(condition:Function, thenSource:Observable, elseSourceOrScheduler:Object = null):Observable {
			return defer(function () :Observable{
				elseSourceOrScheduler ||= empty();
				if (elseSourceOrScheduler is Scheduler) {
					elseSourceOrScheduler = empty(elseSourceOrScheduler as Scheduler);
				}
				return condition() ? thenSource : elseSourceOrScheduler as Observable;
			});
		}
		public static function forIn(sources:Array, resultSelector:Function = null):Observable{
			return Enumerable.forEach(sources, resultSelector).concat();
		}
		public static function whileDo(condition:Function, source:*):Observable {
			return new Enumerable(function ():Enumerator {
				var current:*;
				return Enumerator.create(function ():Boolean {
					if (condition()) {
						current = source;
						return true;
					}
					return false;
				}, function () :*{ return current; });
			}).concat();
		}
		public static function fromEvent(source:IEventDispatcher,eventName:String,useCapture:Boolean = false):Observable{
			return new AnonymousObservable(function(observer:IObserver):IDisposable{
				source.addEventListener(eventName,observer.onNext,useCapture);
				return Disposable.create(function():void{
					source.removeEventListener(eventName,observer.onNext,useCapture);
				});
			});
		}
	}
}