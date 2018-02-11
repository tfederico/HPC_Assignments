int MPI_Broadcast(  void *buffer,           /* INOUT : buffer address            */
                    int count,              /* IN    : buffer size               */
                    MPI_Datatype datatype,  /* IN    : datatype of entry address */
                    int root,               /* IN    : root process (sender)     */
                    MPI_Comm communicator)  /* IN    : communicator              */
{
  int rank, size, tag;
  MPI_Status status;
  MPI_Comm_rank(communicator, rank);
  MPI_Comm_size(communicator, size);

  //initialise tag variable

  if (rank == root) { // I am the root process
    for (int i = 0; i < size; i++) {
      if (i != rank) { //Avoid to send the message to myself
        MPI_Send(buffer, count, datatype, i, tag, communicator);
      }
    }
  }
  else { // I am a receiver process
    MPI_Recv(buffer, count, datatype, root, tag, communicator, &status);
    /* do something with the data */
  }

  return 0;
}
