import NIP01 "../models/NIPS01";
import Filter "../models/Filter";
module {
    private type NIP01 = NIP01.NIP01;

    public type EventType = {
        #NIPS01 : NIP01;
    };
}