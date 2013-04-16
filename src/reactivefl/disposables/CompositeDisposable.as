package reactivefl.disposables
{
	import reactivefl.argsOrArray;
	import reactivefl.i.IDisposable;
	
	public class CompositeDisposable implements IDisposable
	{
		private var isDisposed:Boolean;
		private var disposables:Array;
		public function get length():uint{
			return disposables.length;
		}
		public function CompositeDisposable(...args)
		{
			disposables = argsOrArray(args,0);
			isDisposed = false;
		}
		
		public function dispose():void
		{
			if (!this.isDisposed) {
				this.isDisposed = true;
				var currentDisposables:Array = this.disposables.slice(0);
				this.disposables = [];
				for (var i:uint = 0, len:uint = currentDisposables.length; i < len; i++) {
					currentDisposables[i].dispose();
				}
			}
		}
		
		public function add(item:IDisposable):void{
			if (this.isDisposed) {
				item.dispose();
			} else {
				this.disposables.push(item);
			}
		}
		public function remove(item:IDisposable):Boolean{
			var shouldDispose:Boolean = false;
			if (!this.isDisposed) {
				var idx:int = this.disposables.indexOf(item);
				if (idx !== -1) {
					shouldDispose = true;
					this.disposables.splice(idx, 1);
					item.dispose();
				}
			}
			return shouldDispose;
		}
		public function clear():void{
			var currentDisposables:Array = this.disposables.slice(0);
			this.disposables = [];
			for (var i:uint = 0, len:uint = currentDisposables.length; i < len; i++) {
				currentDisposables[i].dispose();
			}
		}
		public function contains(item:IDisposable):Boolean{
			return disposables.indexOf(item) !== -1;
		}
		public function toArray():Array{
			return disposables.concat();
		}
	}
}