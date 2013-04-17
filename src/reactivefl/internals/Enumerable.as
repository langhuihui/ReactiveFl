package reactivefl.internals
{
	import reactivefl.RFL;
	import reactivefl.concurrency.Scheduler;
	import reactivefl.core.AnonymousObservable;
	import reactivefl.core.Observable;
	import reactivefl.disposables.CompositeDisposable;
	import reactivefl.disposables.Disposable;
	import reactivefl.disposables.SerialDisposable;
	import reactivefl.disposables.SingleAssignmentDisposable;
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObserver;

	public class Enumerable
	{
		public var getEnumerator:Function;
		public function Enumerable(getEnumerator:Function)
		{
			this.getEnumerator = getEnumerator;
		}
		
		public static function forEach(source:Array, selector:Function = null):Enumerable{
			selector ||= RFL.identity;
			return new Enumerable(function ():Enumerator {
				var current:*, index:int = -1;
				return Enumerator.create(
					function ():Boolean {
						if (++index < source.length) {
							current = selector(source[index], index);
							return true;
						}
						return false;
					},
					function ():* { return current; }
				);
			});
		}
		public static function repeat(value:*, repeatCount:int = -1) :Enumerable{
			return new Enumerable(function ():Enumerator {
				var current:*, left:int = repeatCount;
				return Enumerator.create(function ():Boolean {
					if (left === 0) {
						return false;
					}
					if (left > 0) {
						left--;
					}
					current = value;
					return true;
				}, function ():* { return current; });
			});
		};
		public function concat():Observable{
			var sources:Enumerable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var e:Enumerator = sources.getEnumerator(), isDisposed:Boolean = false, subscription:SerialDisposable = new SerialDisposable();
				var cancelable:IDisposable = RFL.immediateScheduler.scheduleRecursive(function (self:Function) :void{
					var current:*, ex:Error, hasNext:Boolean = false;
					if (!isDisposed) {
						try {
							hasNext = e.moveNext();
							if (hasNext) {
								current = e.getCurrent();
							} else {
								e.dispose();
							}
						} catch (exception:Error) {
							ex = exception;
							e.dispose();
						}
					} else {
						return;
					}
					if (ex) {
						observer.onError(ex);
						return;
					}
					if (!hasNext) {
						observer.onCompleted();
						return;
					}
					var d:SingleAssignmentDisposable = new SingleAssignmentDisposable();
					subscription.setDisposable(d);
					d.setDisposable(current.subscribe(
						observer.onNext,
						observer.onError,
						self)
					);
				});
				return new CompositeDisposable(subscription, cancelable,Disposable.create(function ():void {
					isDisposed = true;
					e.dispose();
				}));
			});
		}
		
		public function catchException():Observable
		{
			var sources:Enumerable = this;
			return new AnonymousObservable(function (observer:IObserver):IDisposable {
				var e:Enumerator = sources.getEnumerator(), isDisposed:Boolean = false, lastException:Error;
				var subscription:SerialDisposable = new SerialDisposable();
				var cancelable:IDisposable = RFL.immediateScheduler.scheduleRecursive(function (self:Function):void {
					var current:*, ex:Error, hasNext:Boolean = false;
					if (!isDisposed) {
						try {
							hasNext = e.moveNext();
							if (hasNext) {
								current = e.getCurrent();
							}
						} catch (exception:Error) {
							ex = exception;
						}
					} else {
						return;
					}
					if (ex) {
						observer.onError(ex);
						return;
					}
					if (!hasNext) {
						if (lastException) {
							observer.onError(lastException);
						} else {
							observer.onCompleted();
						}
						return;
					}
					var d:SingleAssignmentDisposable = new SingleAssignmentDisposable();
					subscription.setDisposable(d);
					d.setDisposable(current.subscribe(
						observer.onNext,
						function (exn:Error):void {
							lastException = exn;
							self();
						},
						observer.onCompleted));
				});
				return new CompositeDisposable(subscription, cancelable, Disposable.create(function ():void {
					isDisposed = true;
				}));
			});
		}
	}
}