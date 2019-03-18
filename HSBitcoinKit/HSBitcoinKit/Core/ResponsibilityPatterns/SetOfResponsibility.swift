public class SetOfResponsibility<Id: Hashable, Request, Response> {
    var list = Dictionary<Id, ListElement<Request, Response>>()

    @discardableResult func append(id: Id, element: ListElement<Request, Response>) -> SetOfResponsibility {
        list[id] = element
        return self
    }

    @discardableResult func union(list: Dictionary<Id, ListElement<Request, Response>>) -> SetOfResponsibility {
        self.list.merge(list) { (_, new) in new }

        return self
    }

    func process(id: Id, _ request: Request) -> Response? {
        return list[id]?.process(request)
    }

}

class ListElement<Request, Response> {

    func process(_ request: Request) -> Response? {
        return nil
    }

}
