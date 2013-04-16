package reactivefl.internals
{
	import reactivefl.concurrency.ScheduledItem;

	public class PriorityQueue
	{
		private var items:Vector.<IndexedItem>;
		public function get length():uint{return items.length;}
		private static var count:int = 0;
		public function PriorityQueue(capacity:int)
		{
			items = new Vector.<IndexedItem>();
		}
		public function isHigherPriority (left:uint, right:uint):Boolean {
			return this.items[left].compareTo(this.items[right]) < 0;
		};
		public function percolate (index:int):void {
			if (index >= this.length || index < 0) {
				return;
			}
			var parent:int = index - 1 >> 1;
			if (parent < 0 || parent === index) {
				return;
			}
			if (this.isHigherPriority(index, parent)) {
				var temp:IndexedItem = this.items[index];
				this.items[index] = this.items[parent];
				this.items[parent] = temp;
				this.percolate(parent);
			}
		};
		public function heapify (index:int = 0):void {
			if (index >= this.length || index < 0) {
				return;
			}
			var left:int = 2 * index + 1,
				right:int = 2 * index + 2,
				first:int = index;
			if (left < this.length && this.isHigherPriority(left, first)) {
				first = left;
			}
			if (right < this.length && this.isHigherPriority(right, first)) {
				first = right;
			}
			if (first !== index) {
				var temp:IndexedItem = this.items[index];
				this.items[index] = this.items[first];
				this.items[first] = temp;
				this.heapify(first);
			}
		};
		public function peek ():ScheduledItem {
			return this.items[0].value;
		};
		public function removeAt (index:uint):void {
			this.items[index] = this.items.pop();
			this.heapify();
		};
		public function dequeue ():ScheduledItem {
			return items.shift();
		};
		public function enqueue (item:ScheduledItem):void {
			items.push(new IndexedItem(count++, item));
			this.percolate(length - 1);
		};
		public function remove (item:ScheduledItem):Boolean {
			for (var i:uint = 0; i < this.length; i++) {
				if (this.items[i].value === item) {
					this.removeAt(i);
					return true;
				}
			}
			return false;
		};
	}
}
import reactivefl.concurrency.ScheduledItem;

class IndexedItem{
	public var id:int;
	public var value:ScheduledItem;
	public function IndexedItem(i:int,v:ScheduledItem){
		id = i;
		value =v;
	}
	public function compareTo (other:IndexedItem):int {
		var c:int = this.value.compareTo(other.value);
		if (c == 0) {
			c = this.id - other.id;
		}
		return c;
	};

}