import { app } from './app';
import { connectDb, disconnectDb } from './config/db';

const port = Number(process.env.PORT ?? 4000);

async function bootstrap() {
  await connectDb();

  const server = app.listen(port, () => {
    console.log(`Roamy Backend running at http://localhost:${port}`);
  });

  const shutdown = async () => {
    console.log('Shutting down Roamy Backend...');
    server.close(async () => {
      await disconnectDb();
      process.exit(0);
    });
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

bootstrap().catch((error) => {
  console.error('Failed to start Roamy Backend', error);
  process.exit(1);
});
