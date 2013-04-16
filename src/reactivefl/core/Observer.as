package reactivefl.core
{
	import reactivefl.RFL;
	import reactivefl.i.IObserver;

	internal class Observer implements IObserver
	{
		public function Observer() 
		{
			
		}
		public function onNext(value:*):void{
		}
		public function onError(error:Error):void{
		}
		public function onCompleted():void{
		}
		public function toNotifier():Function{
			return function(n:Notification):*{return n.accept(this);};
		}
		public function asObserver():AnonymousObserver{
			return new AnonymousObserver(onNext,onError,onCompleted);
		}
		public function checked():CheckedObserver{
			return new CheckedObserver(this);
		}
		public static function create(onNext:Function, onError:Function, onCompleted:Function):AnonymousObserver{
			return new AnonymousObserver(onNext || RFL.noop, onError||RFL.defaultError, onCompleted||RFL.noop);
		}
		public static function fromNotifier(handler:Function):AnonymousObserver{
			return new AnonymousObserver(function (x:*):void {
				handler(Notification.createOnNext(x));
			}, function (exception:Error):void {
				handler(Notification.createOnError(exception));
			}, function () :void{
				handler(Notification.createOnCompleted());
			});
		}
	}
}