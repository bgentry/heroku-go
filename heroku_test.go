package heroku

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

type nopCloser struct {
	io.Reader
}

func (nopCloser) Close() error { return nil }

func mockHandler(t *testing.T, resp *http.Response) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer r.Body.Close()
		defer resp.Body.Close()
		// respond with resp
		for k, v := range resp.Header {
			w.Header()[k] = v
		}
		w.WriteHeader(resp.StatusCode)

		var buf bytes.Buffer
		if _, err := buf.ReadFrom(resp.Body); err != nil {
			t.Fatalf("error reading resp body: %s", err)
			return
		}
		_, err := w.Write(buf.Bytes())
		if err != nil {
			t.Fatalf("error writing response: %s", err)
		}
	}
}

func makeResponse(status int, body string) *http.Response {
	return &http.Response{
		StatusCode: status,
		Proto:      "HTTP/1.1",
		Header: http.Header{
			"Content-Type": []string{"application/json;charset=utf-8"},
		},
		Body: nopCloser{bytes.NewBufferString(body)},
	}
}

func TestMockServer(t *testing.T) {
	expected := makeResponse(201, "")

	ts := httptest.NewServer(mockHandler(t, expected))
	defer ts.Close()

	resp, err := http.Get(ts.URL)
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != expected.StatusCode {
		t.Fatalf("expected %d, got %d", expected.StatusCode, resp.StatusCode)
	}
}

func TestRequestId(t *testing.T) {
	c := &Client{}
	req, err := c.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}
	if req.Header.Get("Request-Id") == "" {
		t.Error("Request-Id not set")
	}
}

func TestUserAgent(t *testing.T) {
	c := &Client{}
	req, err := c.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}
	if ua := req.Header.Get("User-Agent"); ua != DefaultUserAgent {
		t.Errorf("Default User-Agent expected %q, got %q", DefaultUserAgent, ua)
	}

	// try a custom User-Agent
	customAgent := "custom-client 2.1 " + DefaultUserAgent
	c.UserAgent = customAgent
	req, err = c.NewRequest("GET", "/", nil)
	if err != nil {
		t.Fatal(err)
	}
	if ua := req.Header.Get("User-Agent"); ua != customAgent {
		t.Errorf("User-Agent expected %q, got %q", customAgent, ua)
	}
}

func TestGet(t *testing.T) {
	expected := makeResponse(200, "{\"omg\": \"wtf\"}")

	ts := httptest.NewServer(mockHandler(t, expected))
	defer ts.Close()
	c := &Client{}
	c.URL = ts.URL

	var v struct {
		Omg string
	}
	err := c.Get(&v, "/")
	if err != nil {
		t.Fatal(err)
	}
	if v.Omg != "wtf" {
		t.Errorf("expected %q, got %q", "wtf", v.Omg)
	}
}
