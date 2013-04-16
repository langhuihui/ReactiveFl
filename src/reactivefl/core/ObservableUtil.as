package reactivefl.core
{
	import reactivefl.argsOrArray;
	import reactivefl.concurrency.Scheduler;
	import reactivefl.disposables.CompositeDisposable;
	import reactivefl.disposables.Disposable;
	import reactivefl.disposables.SerialDisposable;
	import reactivefl.disposables.SingleAssignmentDisposable;
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObservable;
	import reactivefl.i.IObserver;

	public class ObservableUtil
	{
		public function ObservableUtil()
		{
		}
		public static function throwException(exception:Error, scheduler:Scheduler = null):Observable {
			scheduler ||= Scheduler.immediate;
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
			scheduler ||= Scheduler.currentThread;
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
			scheduler ||= Scheduler.currentThread;
			return returnValue(value, scheduler).repeat(repeatCount);
		}
		public static function returnValue(value:*, scheduler:Scheduler):Observable {
			scheduler ||= Scheduler.immediate;
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
				scheduler = Scheduler.immediate;
				sources = args.slice(1);
			} else if (args[0].now) {
				scheduler = args[0];
				sources = args.slice(1);
			} else {
				scheduler = Scheduler.immediate;
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
				cancelable:IDisposable = Scheduler.immediate.scheduleRecursive(function (self:Function):void {
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
			scheduler ||= Scheduler.immediate;
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
		};
		
		public static function concat(items:Array):Observable
		{
			// TODO Auto Generated method stub
			return null;
		}
	}
}