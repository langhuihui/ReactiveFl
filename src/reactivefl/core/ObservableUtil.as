package reactivefl.core
{
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.IEventDispatcher;
	
	import mx.binding.utils.BindingUtils;
	import mx.binding.utils.ChangeWatcher;
	
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
		public static function fromArray(array:Array, scheduler:Scheduler = null):Observable{
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
			} else if (args[0] is Scheduler) {
				scheduler = args[0] as Scheduler;
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
		//time
		private static function observableTimerDateAndPeriod(dueTime:Number, period:Number, scheduler:Scheduler):Observable {
			var p:Number = Scheduler.normalize(period);
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var count:Number = 0, d:Number = dueTime;
				return scheduler.scheduleRecursiveWithAbsolute(d, function (self:Function):void {
					var now:Number;
					if (p > 0) {
						now = scheduler.now();
						d = d + p;
						if (d <= now) {
							d = now + p;
						}
					}
					observer.onNext(count++);
					self(d);
				});
			});
		}
		
		private static function observableTimerTimeSpanAndPeriod(dueTime:Number, period:Number, scheduler:Scheduler):Observable {
			if (dueTime === period) {
				return new AnonymousObservable(function (observer:IObserver):IDisposable {
					return scheduler.schedulePeriodicWithState(0, period, function (count:int):int {
						observer.onNext(count);
						return count + 1;
					});
				});
			}
			return ObservableUtil.defer(function () :Observable{
				return observableTimerDateAndPeriod(scheduler.now() + dueTime, period, scheduler);
			});
		}
		private static function observableTimerDate(dueTime:Number, scheduler:Scheduler):Observable {
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return scheduler.scheduleWithAbsolute(dueTime, function ():void {
					observer.onNext(0);
					observer.onCompleted();
				});
			});
		}
		private static function observableTimerTimeSpan(dueTime:Number, scheduler:Scheduler):Observable {
			var d:Number = Scheduler.normalize(dueTime);
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				return scheduler.scheduleWithRelative(d, function ():void {
					observer.onNext(0);
					observer.onCompleted();
				});
			});
		}
		public static function interval(period:Number, scheduler:Scheduler = null):Observable{
			return observableTimerTimeSpanAndPeriod(period,period,scheduler||RFL.timeoutScheduler);
		}
		public static function timer(dueTime:Object, periodOrScheduler:Object, scheduler:Scheduler = null):Observable {
			var period:Number;
			scheduler ||= RFL.timeoutScheduler;
			if (periodOrScheduler !=null && typeof periodOrScheduler === 'number') {
				period = Number(periodOrScheduler);
			} else if (periodOrScheduler !=null) {
				scheduler = periodOrScheduler as Scheduler;
			}
			if (dueTime is Date && isNaN(period)) {
				return observableTimerDate((dueTime as Date).getTime(), scheduler);
			}
			if (dueTime is Date && isNaN(period)) {
				period = Number(periodOrScheduler);
				return observableTimerDateAndPeriod((dueTime as Date).getTime(), period, scheduler);
			}
			if (isNaN(period)) {
				return observableTimerTimeSpan(Number(dueTime), scheduler);
			}
			return observableTimerTimeSpanAndPeriod(Number(dueTime), period, scheduler);
		}
		
		//flash
		public static function fromEvent(source:IEventDispatcher,eventName:String,useCapture:Boolean = false):Observable{
			return new AnonymousObservable(function(observer:IObserver):IDisposable{
				source.addEventListener(eventName,observer.onNext,useCapture);
				return Disposable.create(function():void{
					source.removeEventListener(eventName,observer.onNext,useCapture);
				});
			});
		}
		public static function fromEnterFrame(displayObject:DisplayObject,interval:uint = 0):Observable{
			if(interval>0)
				return fromEvent(displayObject,Event.ENTER_FRAME).windowWithCount(1,interval);
			return fromEvent(displayObject,Event.ENTER_FRAME);
		}
		public static function fromBinding(host:Object,chain:Object):Observable{
			return new AnonymousObservable(function(observer:IObserver):IDisposable{
				var watcher:ChangeWatcher = BindingUtils.bindSetter(observer.onNext,host,chain);
				return Disposable.create(watcher.unwatch);
			});
		}
	}
}