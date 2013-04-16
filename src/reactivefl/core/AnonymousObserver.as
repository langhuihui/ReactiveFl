package reactivefl.core
{
	public class AnonymousObserver extends AbstractObserver
	{
		private var _onNext:Function,_onError:Function,_onCompleted:Function;
		public function AnonymousObserver(onNext:Function, onError:Function, onCompleted:Function)
		{
			super();
			_onNext = onNext;
			_onError = onError;
			_onCompleted = onCompleted;
		}
		override protected function next(value:*):void{
			_onNext(value);
		}
		override protected function error(error:Error):void{
			_onError(error);
		}
		override protected function completed():void{
			_onCompleted();
		}
	}
}