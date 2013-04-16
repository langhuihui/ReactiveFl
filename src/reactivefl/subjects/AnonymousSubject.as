package reactivefl.subjects
{
	import reactivefl.core.Observable;
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObserver;

	public class AnonymousSubject extends Observable implements IObserver
	{
		private var observer:IObserver;
		private var observable:Observable;
		public function AnonymousSubject(observer:IObserver, observable:Observable)
		{
			this.observer = observer;
			this.observable = observable;
			super( function (observer:IObserver):IDisposable {
				return this.observable.subscribe(observer);
			});
		}
		public function onCompleted():void{
			observer.onCompleted();
		}
		public function onNext(o:*):void{
			observer.onNext(o);
		}
		public function onError(e:Error):void{
			observer.onError(e);
		}
	}
}