enum ConflictResolution {
    case ignore(needToUpdate: [Transaction])
    case accept(needToMakeInvalid: [Transaction])
}
