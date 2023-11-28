import JSON "mo:serde/JSON";
import Candid "mo:serde/Candid";
import Error "mo:base/Error";

module {
    public type NIP01 = {
        id : Text;
        pubkey : Text;
        created_at : Nat64;
        kind : Nat64;
        tags : [[Text]];
        content : Text;
        sig : Text;
    };

    public func toJSON(nip : NIP01) : async* Text {
        let blob = to_candid (nip);

        let field_keys = ["id", "pubkey", "created_at", "kind", "tags", "content", "sig"];
        let result = JSON.toText(blob, field_keys, null);
        switch (result) {
            case (#ok(value)) value;
            case (#err(value)) throw (Error.reject(value));
        };
    };

    public func fromJSON(json : Text) : async* NIP01 {
        let result = JSON.fromText(json, null);
        switch (result) {
            case (#ok(blob)) {
                let nip : ?NIP01 = from_candid (blob);
                switch (nip) {
                    case (?nip) nip;
                    case (_) throw (Error.reject("Error Parsing JSON"));
                };
            };
            case (#err(value)) throw (Error.reject(value));
        };
    };
};
