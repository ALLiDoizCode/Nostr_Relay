module {
    public func service(canister : Text) : actor {
        getCanistersByPK : query (Text) -> async [Text];
    } {
        return actor (canister) : actor {
            getCanistersByPK : query (Text) -> async [Text];
        };
    };
}