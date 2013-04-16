package reactivefl.subjects
{
	import reactivefl.RFL;
	import reactivefl.core.Observable;
	import reactivefl.disposables.Disposable;
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObserver;
	
	public class Subject extends Observable implements IDisposable, IObserver
	{
		public var isStopped:Boolean;
		public var observers:Array;
		public var exception:Error;
		public var isDisposed:Boolean;
		
		public function Subject()
		{
			function subscribe(observer:IObserver):IDisposable
			{
				RFL.checkDisposed(isDisposed);
				if (!this.isStopped) {
					this.observers.push(observer);
					return new InnerSubscription(this, observer);
				}
				if (this.exception) {
					observer.onError(this.exception);
					return Disposable.empty;
				}
				observer.onCompleted();
				return Disposable.empty;
			}
			super(subscribe);
			this.isDisposed = false;
			this.isStopped = false;
			this.observers = [];
		}
		public function onCompleted():void{
			RFL.checkDisposed(isDisposed);
			if (!this.isStopped) {
				var os:Array = this.observers.slice(0);
				this.isStopped = true;
				for (var i:int = 0, len:uint = os.length; i < len; i++) {
					os[i].onCompleted();
				}
				this.observers = [];
			}
		}
		public function onError(exception:Error):void {
			RFL.checkDisposed(isDisposed);
			if (!this.isStopped) {
				var os:Array = this.observers.slice(0);
				this.isStopped = true;
				this.exception = exception;
				for (var i:int = 0, len:uint = os.length; i < len; i++) {
					os[i].onError(exception);
				}
				
				this.observers = [];
			}
		}
		public function onNext(value:*):void {
			RFL.checkDisposed(isDisposed);
			if (!this.isStopped) {
				var os:Array = this.observers.slice(0);
				for (var i:int = 0, len:uint = os.length; i < len; i++) {
					os[i].onNext(value);
				}
			}
		}
		public function dispose():void{
			this.isDisposed = true;
			this.observers = null;
		}
		public static function create(observer:IObserver, observable:Observable):AnonymousSubject {
			return new AnonymousSubject(observer, observable);
		};

	}
}