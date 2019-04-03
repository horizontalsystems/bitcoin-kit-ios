public class SetOfResponsibility<Request, Response> {
    private var list = Dictionary<String, ListElement<Request, Response>>()

    @discardableResult func append(element: ListElement<Request, Response>) -> SetOfResponsibility {
        list[element.id] = element
        return self
    }

    @discardableResult func union(_ set: SetOfResponsibility) -> SetOfResponsibility {
        self.list.merge(set.list) { (_, new) in new }

        return self
    }

    func process(id: String, _ request: Request) -> Response? {
        return list[id]?.process(request)
    }

}

class ListElement<Request, Response> {
    var id: String { fatalError("Not determined network message command!") }

    func process(_ request: Request) -> Response? {
        return nil
    }

}
