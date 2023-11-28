import JSON "mo:serde/JSON";
import Candid "mo:serde/Candid";
import Error "mo:base/Error";

module {
    public type Filter = {
        ids: [Text];
        authors: [Text];
        kinds: [Nat64];
        tagValue: TagValue;
        since: Nat64;
        until: Nat64;
        limit: Nat64;
    };

    public type TagValue = {
        #e:[Text];
        #p:[Text];
    };

    public func toJSON(nip : Filter) : async* Text {
        let blob = to_candid (nip);

        let field_keys = ["ids", "authors", "kinds", "tagValue", "since", "until", "limit"];
        let result = JSON.toText(blob, field_keys, null);
        switch (result) {
            case (#ok(value)) value;
            case (#err(value)) throw (Error.reject(value));
        };
    };

    public func fromJSON(json : Text) : async* Filter {
        let result = JSON.fromText(json, null);
        switch (result) {
            case (#ok(blob)) {
                let filter : ?Filter = from_candid (blob);
                switch (filter) {
                    case (?filter) filter;
                    case (_) throw (Error.reject("Error Parsing JSON: "#json));
                };
            };
            case (#err(value)) throw (Error.reject(value));
        };
    };
}