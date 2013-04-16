package reactivefl.i
{
	public interface IObservable
	{
		function subscribe( observerOrOnNext:Object,onError:Function = null,onCompleted:Function = null):IDisposable;
	}
}