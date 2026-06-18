const request = require('supertest');
const { app, server } = require('../src/index');

afterAll(() => {
  server.close();
});

describe('Hello World Azure App', () => {
  test('GET / should return hello message', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('Hello from Azure!');
    expect(res.body).toHaveProperty('timestamp');
    expect(res.body).toHaveProperty('environment');
  });

  test('GET /health should return healthy status', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('healthy');
    expect(res.body).toHaveProperty('uptime');
    expect(res.body).toHaveProperty('timestamp');
  });

  test('GET /api/info should return app metadata', async () => {
    const res = await request(app).get('/api/info');
    expect(res.statusCode).toBe(200);
    expect(res.body.app).toBe('hello-world-azure');
    expect(res.body.version).toBe('1.0.0');
    expect(res.body).toHaveProperty('runtime');
    expect(res.body).toHaveProperty('platform');
  });
});
