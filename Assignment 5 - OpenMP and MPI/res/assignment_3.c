int MPI_Circular_Broadcast(  void *buffer,          /* INOUT : buffer address            */
                             int count,             /* IN    : buffer size               */
                             MPI_Datatype datatype, /* IN    : datatype of entry address */
                             int root,              /* IN    : root process (sender)     */
                             MPI_Comm communicator) /* IN    : communicator              */
{
  int rank, size, tag;
  MPI_Status status;
  MPI_Comm_rank(communicator, rank);
  MPI_Comm_size(communicator, size);

  //initialise tag variable

  int neighboor_lh, neighboor_rh;
  neighboor_rh = (rank + 1) % size;
  neighboor_lh = (rank - 1) % size;
  if (rank == root) { //Root process sends to neighboors
    MPI_Send(buffer, count, datatype, neighboor_lh, tag, communicator);
    MPI_Send(buffer, count, datatype, neighboor_rh, tag, communicator);
  }
  else if (rank < size/2){ // Circularly increasing MPI ranks
    MPI_Recv(buffer, count, datatype, neighboor_lh, tag, communicator, &status);
    // Send message to the neighboor that has bigger MPI rank
    MPI_Send(buffer, count, datatype, neighboor_rh, tag, communicator);
  }
  else if (rank > size/2){  // Circularly decreasing MPI ranks
    MPI_Recv(buffer, count, datatype, neighboor_rh, tag, communicator, &status);
    // Send message to the neighboor that has smaller MPI rank
    MPI_Send(buffer, count, datatype, neighboor_lh, tag, communicator);
  }
  else{ // Last nodes in the ring to reach

    /*
      By default, last node receive the message from the neighboor on its right
      in both cases size is even (one more node to reach) or odd (two nodes
      remaining)
    */

    MPI_Recv(buffer, count, datatype, neighboor_rh, tag, communicator, &status);
  }

  return 0;
}
