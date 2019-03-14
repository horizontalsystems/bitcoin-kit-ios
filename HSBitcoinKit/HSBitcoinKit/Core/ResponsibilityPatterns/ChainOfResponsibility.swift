class ChainOfResponsibility<Request, Response> {
    var successor: ChainOfResponsibility<Request, Response>?

    @discardableResult func attach(to element: ChainOfResponsibility<Request, Response>) -> ChainOfResponsibility<Request, Response> {
        element.successor = self
        return element
    }

    func process(_ request: Request) -> Response? {
        return nil
    }

    func handle(_ request: Request) -> Response? {
        return process(request) ?? successor?.handle(request)
    }

}
