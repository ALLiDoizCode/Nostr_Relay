import EventType "../../Nostr_Relay_backend/models/EventType";

module {

    type EventType = EventType.EventType;

    public func service(canister : Text) : actor {
        addEntity : shared (EventType) -> async Text;
        skExists : query (Text) -> async Bool;
        fetchEvents : query (Text, Text, Nat) -> async {
            events : [EventType];
            sk : ?Text;
        };
    } {
        return actor (canister) : actor {
            addEntity : shared (EventType) -> async Text;
            skExists : query (Text) -> async Bool;
            fetchEvents : query (Text, Text, Nat) -> async {
                events : [EventType];
                sk : ?Text;
            };
        };
    };
};
