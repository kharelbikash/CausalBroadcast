# CausalBroadcast
Message Passing algorithm in Distributed Asynchronous System with vector clock.

If broadcast-send(m1) ⇒S broadcast-send(m2), then no process receives m2 before m1. Implies single-source FIFO but not total ordering.
