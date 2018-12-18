import Foundation

public extension Array {
    /// Returns a new `Array` made by appending a given element to the `Array`.
    public func appending(_ newElement: Element) -> Array {
        var a = Array(self)
        a.append(newElement)
        return a
    }
    
    /// Returns a new `Array` made by adding the elements of a sequence to the end of the array.
    public func appending(_ newElements: [Element]) -> Array {
        var a = Array(self)
        a.append(contentsOf: newElements)
        return a
    }
}
