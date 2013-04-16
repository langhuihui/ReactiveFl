package reactivefl.core
{
	import reactivefl.disposables.CompositeDisposable;
	import reactivefl.disposables.RefCountDisposable;
	import reactivefl.i.IDisposable;
	import reactivefl.i.IObservable;
	import reactivefl.i.IObserver;

	public class GroupedObservable extends Observable
	{
		private var key:*;
		private var underlyingObservable:IObservable;
		public function GroupedObservable(key:*, underlyingObservable:IObservable, mergedDisposable:RefCountDisposable = null) {
			super(underlyingObservable.subscribe);
			this.key = key;
			this.underlyingObservable = !mergedDisposable ?
				underlyingObservable :
				new AnonymousObservable(function (observer:IObserver):IDisposable {
					return new CompositeDisposable(mergedDisposable.getDisposable(), underlyingObservable.subscribe(observer));
				});
		}
	}
}