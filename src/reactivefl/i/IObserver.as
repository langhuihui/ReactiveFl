package reactivefl.i
{
	public interface IObserver
	{
		function onCompleted():void;
		function onNext(o:*):void;
		function onError(e:Error):void;
	}
}